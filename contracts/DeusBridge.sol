// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

// =================================================================================================================
//  _|_|_|    _|_|_|_|  _|    _|    _|_|_|      _|_|_|_|  _|                                                       |
//  _|    _|  _|        _|    _|  _|            _|            _|_|_|      _|_|_|  _|_|_|      _|_|_|    _|_|       |
//  _|    _|  _|_|_|    _|    _|    _|_|        _|_|_|    _|  _|    _|  _|    _|  _|    _|  _|        _|_|_|_|     |
//  _|    _|  _|        _|    _|        _|      _|        _|  _|    _|  _|    _|  _|    _|  _|        _|           |
//  _|_|_|    _|_|_|_|    _|_|    _|_|_|        _|        _|  _|    _|    _|_|_|  _|    _|    _|_|_|    _|_|_|     |
// =================================================================================================================
// ======================= DEUS Bridge ======================
// ==========================================================
// DEUS Finance: https://github.com/DeusFinance

// Primary Author(s)
// Sadegh: https://github.com/sadeghte
// Reza: https://github.com/bakhshandeh
// Vahid: https://github.com/vahid-dev
// Mahdi: https://github.com/Mahdi-HF

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "./interfaces/IDeusBridge.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/IDEIStablecoin.sol";

/**
 * @title Permissionless ERC20 Bridge
 * @author DEUS Finance
 * @notice Bridge any ERC20 completely permissionlessly
 * @dev Released under DEUS v2
 */
contract DeusBridge is IDeusBridge, Ownable, Pausable {
    using ECDSA for bytes32;

    /* ========== STATE VARIABLES ========== */

    uint public lastTxId = 0;  // unique id for deposit tx
    uint public chainId;  // current chainId
    uint public minReqSigs;  // minimum required TSS
    uint public scale = 1e6;
    uint public bridgeReserve;  // it handles buyback & recollateralize on dei pools
    address public muonContract;  // muon signature verifier contract
    address public deiAddress;
    uint8   public ETH_APP_ID;  // muon's eth app id
    bool    public mintable;  // use mint functions instead of transfer
    // we assign a unique ID to each chain (default is CHAIN-ID)
    mapping (uint => address) public sideContracts;
    // tokenId => tokenContractAddress
    mapping(uint => address)  public tokens;
    mapping(uint => Transaction) private txs;
    // user => (destination chain => user's txs id)
    mapping(address => mapping(uint => uint[])) private userTxs;
    // source chain => (tx id => false/true)
    mapping(uint => mapping(uint => bool)) public claimedTxs;
    // tokenId => tokenFee
    mapping(uint => uint) public fee;
    // tokenId => collectedFee
    mapping(uint => uint) public collectedFee;

    /* ========== EVENTS ========== */

    event Deposit(
        address indexed user,
        uint tokenId,
        uint amount,
        uint indexed toChain,
        uint txId
    );
    event Claim(
        address indexed user,
        uint tokenId,
        uint amount,
        uint indexed fromChain,
        uint txId
    );
    event BridgeReserveSet(uint bridgeReserve, uint _bridgeReserve);

    /* ========== CONSTRUCTOR ========== */

    /**
     * @dev Deploy bridge as DEI bridge or ERC20 bridge
     * @param minReqSigs_ Minimum required TSS
     * @param bridgeReserve_ how much DEI can the bridge hold
     * @param ETH_APP_ID_ App Identifier within Muon
     * @param muon_ Muon contract for signature validation
     * @param deiAddress_ DEI Address
     * @param mintable_ truthy for DEI bridge / false for ERC20 bridge
     */
    constructor(
        uint minReqSigs_,
        uint bridgeReserve_,
        uint8 ETH_APP_ID_,
        address muon_,
        address deiAddress_,
        bool mintable_
    ) {
        chainId = getExecutingChainID();
        minReqSigs = minReqSigs_;
        bridgeReserve = bridgeReserve_;
        ETH_APP_ID = ETH_APP_ID_;
        muonContract = muon_;
        deiAddress = deiAddress_;
        mintable = mintable_;
    }

    /* ========== PUBLIC FUNCTIONS ========== */

    /**
     * @notice Deposit an amount of ERC20 tokens
     * @dev This function will be replaced by a regular `transfer` in the future
     * @param amount The amount of tokens to deposit
     * @param toChain The chainId of the destination chain
     * @param tokenId Identifier that's shared across chains for this token
     * @return txId Identifier used by Muon to access state when bridging
     */
    function deposit(
        uint amount,
        uint toChain,
        uint tokenId
    ) external returns (uint txId) {
        txId = _deposit(msg.sender, amount, toChain, tokenId);
        emit Deposit(msg.sender, tokenId, amount, toChain, txId);
    }

    /**
     * @notice Deposit an amount of ERC20 tokens via a proxy
     * @dev Same as `deposit` but for proxies
     */
    function depositFor(
        address user,
        uint amount,
        uint toChain,
        uint tokenId
    ) external returns (uint txId) {
        txId = _deposit(user, amount, toChain, tokenId);
        emit Deposit(user, tokenId, amount, toChain, txId);
    }

    /**
     * @dev Interally called by `deposit` and/or `depositFor`
     */
    function _deposit(
        address user,
        uint amount,
        uint toChain,
        uint tokenId
    )
        internal
        whenNotPaused()
        returns (uint txId)
    {
        require(sideContracts[toChain] != address(0), "[Bridge]: toChain is not a recognized source");
        require(toChain != chainId, "[Bridge]: toChain cannot be current chainId");
        require(tokens[tokenId] != address(0), "[Bridge]: unknown tokenId");

        IERC20 token = IERC20(tokens[tokenId]);
        if (mintable) {
            token.pool_burn_from(msg.sender, amount);
            if (tokens[tokenId] == deiAddress) {
                bridgeReserve -= amount;
            }
        } else {
            token.transferFrom(msg.sender, address(this), amount);
        }

        if (fee[tokenId] > 0) {
            uint feeAmount = amount * fee[tokenId] / scale;
            amount -= feeAmount;
            collectedFee[tokenId] += feeAmount;
        }

        txId = ++lastTxId;
        txs[txId] = Transaction({
            txId: txId,
            tokenId: tokenId,
            fromChain: chainId,
            toChain: toChain,
            amount: amount,
            user: user,
            txBlockNo: block.number
        });
        userTxs[user][toChain].push(txId);
    }

    function claim(
        address user,
        uint amount,
        uint fromChain,
        uint toChain,
        uint tokenId,
        uint txId,
        bytes calldata _reqId,
        SchnorrSign[] calldata sigs
    ) external {
        require(sideContracts[fromChain] != address(0), '[Bridge]: fromChain is not a recognized source');
        require(toChain == chainId, "[Bridge]: toChain should be current chainId");
        require(sigs.length >= minReqSigs, "[Bridge]: insufficient number of signatures");

        {
            bytes32 hash = keccak256(
            abi.encodePacked(
                abi.encodePacked(sideContracts[fromChain], txId, tokenId, amount),
                abi.encodePacked(fromChain, toChain, user, ETH_APP_ID)
                )
            );

            IMuonV02 muon = IMuonV02(muonContract);
            require(muon.verify(_reqId, uint(hash), sigs), "[Bridge]: unable to verify signatures");
        }

        require(!claimedTxs[fromChain][txId], "[Bridge]: tokens are already claimed");
        require(tokens[tokenId] != address(0), "[Bridge]: unknown tokenId");

        IERC20 token = IERC20(tokens[tokenId]);
        if (mintable) {
            token.pool_mint(user, amount);
            if (tokens[tokenId] == deiAddress) {
                bridgeReserve += amount;
            }
        } else {
            token.transfer(user, amount);
        }

        claimedTxs[fromChain][txId] = true;
        emit Claim(user, tokenId, amount, fromChain, txId);
    }


    /* ========== VIEWS ========== */

    // This function use pool feature to handle buyback and recollateralize on DEI minter pool
    function getCollateralBalance(uint collat_usd_price) public view returns (uint) {
        uint collateralRatio = IDEIStablecoin(deiAddress).global_collateral_ratio();
        return bridgeReserve * collateralRatio / 1e6;
    }

    function getPendingTransactions(
        uint fromChain,
        uint[] calldata ids
    ) public view returns (bool[] memory unclaimedIds) {
        unclaimedIds = new bool[](ids.length);
        for(uint i=0; i < ids.length; i++){
            unclaimedIds[i] = claimedTxs[fromChain][ids[i]];
        }
    }

    function getUserTransactions(
        address user,
        uint toChain
    ) public view returns (uint[] memory) {
        return userTxs[user][toChain];
    }

    function getTransaction(uint txId_) public view returns(
        uint txId,
        uint tokenId,
        uint amount,
        uint fromChain,
        uint toChain,
        address user,
        uint txBlockNo,
        uint currentBlockNo
    ){
        txId = txs[txId_].txId;
        tokenId = txs[txId_].tokenId;
        amount = txs[txId_].amount;
        fromChain = txs[txId_].fromChain;
        toChain = txs[txId_].toChain;
        user = txs[txId_].user;
        txBlockNo = txs[txId_].txBlockNo;
        currentBlockNo = block.number;
    }

    function getExecutingChainID() public view returns (uint) {
        uint id;
        assembly {
            id := chainid()
        }
        return id;
    }


    /* ========== RESTRICTED FUNCTIONS ========== */

    function setBridgeReserve(uint bridgeReserve_) external onlyOwner {
        emit BridgeReserveSet(bridgeReserve, bridgeReserve_);

        bridgeReserve = bridgeReserve_;
    }

    function setToken(uint tokenId, address tokenAddress) external onlyOwner {
        tokens[tokenId] = tokenAddress;
    }

    function setChainId(uint chainId_) external onlyOwner {
        chainId = chainId_;
        delete sideContracts[chainId_];
    }

    function setFee(uint tokenId, uint fee_) external onlyOwner {
        fee[tokenId] = fee_;
    }

    function setDeiAddress(address deiAddress_) external onlyOwner {
        deiAddress = deiAddress_;
    }

    function setMinReqSigs(uint minReqSigs_) external onlyOwner {
        minReqSigs = minReqSigs_;
    }

    function setSideContract(uint chainId_, address address_) external onlyOwner {
        require (chainId_ != chainId, "[Bridge]: sideContract chainId cannot be current chainId");
        sideContracts[chainId_] = address_;
    }

    function setMintable(bool mintable_) external onlyOwner {
        mintable = mintable_;
    }

    function setEthAppId(uint8 ETH_APP_ID_) external onlyOwner {
        ETH_APP_ID = ETH_APP_ID_;
    }

    function setMuonContract(address muonContract_) external onlyOwner {
        muonContract = muonContract_;
    }

    function pause() external onlyOwner { super._pause(); }

    function unpause() external onlyOwner { super._unpause(); }

    function withdrawFee(uint tokenId, address to) external onlyOwner {
        require(collectedFee[tokenId] > 0, "[Bridge]: there is no fee to collect");

        IERC20(tokens[tokenId]).pool_mint(to, collectedFee[tokenId]);
        collectedFee[tokenId] = 0;
    }

    function emergencyWithdrawETH(address to, uint amount) external onlyOwner {
        require(to != address(0));
        payable(to).transfer(amount);
    }

    function emergencyWithdrawERC20Tokens(address tokenAddr, address to, uint amount) external onlyOwner {
        require(to != address(0));
        IERC20(tokenAddr).transfer(to, amount);
    }
}
