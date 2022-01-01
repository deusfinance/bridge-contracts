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

contract DeusBridge is IDeusBridge, Ownable, Pausable {
    using ECDSA for bytes32;

    /* ========== STATE VARIABLES ========== */

    uint256 public lastTxId = 0; // unique id for deposit tx
    uint256 public network; // current chain id
    uint256 public minReqSigs; // minimum required tss
    uint256 public scale = 1e6;
    uint256 public bridgeReserve; // it handles buyback & recollaterlize on dei pools
    address public muonContract; // muon signature verifier contract
    address public deiAddress;
    uint8 public ETH_APP_ID; // muon's eth app id
    bool public mintable; // use mint functions instead of transfer
    // we assign a unique ID to each chain (default is CHAIN-ID)
    mapping(uint256 => address) public sideContracts;
    // tokenId => tokenContractAddress
    mapping(uint256 => address) public tokens;
    mapping(uint256 => Transaction) private txs;
    // user => (destination chain => user's txs id)
    mapping(address => mapping(uint256 => uint256[])) private userTxs;
    // source chain => (tx id => false/true)
    mapping(uint256 => mapping(uint256 => bool)) public claimedTxs;
    // tokenId => tokenFee
    mapping(uint256 => uint256) public fee;
    // tokenId => collectedFee
    mapping(uint256 => uint256) public collectedFee;

    /* ========== EVENTS ========== */
    event Deposit(
        address indexed user,
        uint256 tokenId,
        uint256 amount,
        uint256 indexed toChain,
        uint256 txId
    );
    event DepositWithReferralCode(
        address indexed user,
        uint256 tokenId,
        uint256 amount,
        uint256 indexed toChain,
        uint256 txId,
        uint256 referralCode
    );
    event Claim(
        address indexed user,
        uint256 tokenId,
        uint256 amount,
        uint256 indexed fromChain,
        uint256 txId
    );
    event BridgeReserveSet(uint256 bridgeReserve, uint256 _bridgeReserve);

    /* ========== CONSTRUCTOR ========== */

    constructor(
        uint256 minReqSigs_,
        uint256 bridgeReserve_,
        uint8 ETH_APP_ID_,
        address muon_,
        address deiAddress_,
        bool mintable_
    ) {
        network = getExecutingChainID();
        minReqSigs = minReqSigs_;
        bridgeReserve = bridgeReserve_;
        ETH_APP_ID = ETH_APP_ID_;
        muonContract = muon_;
        deiAddress = deiAddress_;
        mintable = mintable_;
    }

    /* ========== PUBLIC FUNCTIONS ========== */

    function deposit(
        uint256 amount,
        uint256 toChain,
        uint256 tokenId
    ) external returns (uint256 txId) {
        txId = _deposit(msg.sender, amount, toChain, tokenId);
        emit Deposit(msg.sender, tokenId, amount, toChain, txId);
    }

    function depositFor(
        address user,
        uint256 amount,
        uint256 toChain,
        uint256 tokenId
    ) external returns (uint256 txId) {
        txId = _deposit(user, amount, toChain, tokenId);
        emit Deposit(user, tokenId, amount, toChain, txId);
    }

    function deposit(
        uint256 amount,
        uint256 toChain,
        uint256 tokenId,
        uint256 referralCode
    ) external returns (uint256 txId) {
        txId = _deposit(msg.sender, amount, toChain, tokenId);
        emit DepositWithReferralCode(
            msg.sender,
            tokenId,
            amount,
            toChain,
            txId,
            referralCode
        );
    }

    function depositFor(
        address user,
        uint256 amount,
        uint256 toChain,
        uint256 tokenId,
        uint256 referralCode
    ) external returns (uint256 txId) {
        txId = _deposit(user, amount, toChain, tokenId);
        emit DepositWithReferralCode(
            user,
            tokenId,
            amount,
            toChain,
            txId,
            referralCode
        );
    }

    function _deposit(
        address user,
        uint256 amount,
        uint256 toChain,
        uint256 tokenId
    ) internal whenNotPaused returns (uint256 txId) {
        require(
            sideContracts[toChain] != address(0),
            "Bridge: unknown toChain"
        );
        require(toChain != network, "Bridge: selfDeposit");
        require(tokens[tokenId] != address(0), "Bridge: unknown tokenId");

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
            uint256 feeAmount = (amount * fee[tokenId]) / scale;
            amount -= feeAmount;
            collectedFee[tokenId] += feeAmount;
        }

        txId = ++lastTxId;
        txs[txId] = Transaction({
            txId: txId,
            tokenId: tokenId,
            fromChain: network,
            toChain: toChain,
            amount: amount,
            user: user,
            txBlockNo: block.number
        });
        userTxs[user][toChain].push(txId);
    }

    function claim(
        address user,
        uint256 amount,
        uint256 fromChain,
        uint256 toChain,
        uint256 tokenId,
        uint256 txId,
        bytes calldata _reqId,
        SchnorrSign[] calldata sigs
    ) external {
        require(
            sideContracts[fromChain] != address(0),
            "Bridge: source contract not exist"
        );
        require(toChain == network, "Bridge: toChain should equal network");
        require(
            sigs.length >= minReqSigs,
            "Bridge: insufficient number of signatures"
        );

        {
            bytes32 hash = keccak256(
                abi.encodePacked(
                    abi.encodePacked(
                        sideContracts[fromChain],
                        txId,
                        tokenId,
                        amount
                    ),
                    abi.encodePacked(fromChain, toChain, user, ETH_APP_ID)
                )
            );

            IMuonV02 muon = IMuonV02(muonContract);
            require(
                muon.verify(_reqId, uint256(hash), sigs),
                "Bridge: not verified"
            );
        }

        require(!claimedTxs[fromChain][txId], "Bridge: already claimed");
        require(tokens[tokenId] != address(0), "Bridge: unknown tokenId");

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
    function collatDollarBalance(uint256 collat_usd_price)
        public
        view
        returns (uint256)
    {
        uint256 collateralRatio = IDEIStablecoin(deiAddress)
            .global_collateral_ratio();
        return (bridgeReserve * collateralRatio) / 1e6;
    }

    function pendingTxs(uint256 fromChain, uint256[] calldata ids)
        public
        view
        returns (bool[] memory unclaimedIds)
    {
        unclaimedIds = new bool[](ids.length);
        for (uint256 i = 0; i < ids.length; i++) {
            unclaimedIds[i] = claimedTxs[fromChain][ids[i]];
        }
    }

    function getUserTxs(address user, uint256 toChain)
        public
        view
        returns (uint256[] memory)
    {
        return userTxs[user][toChain];
    }

    function getTransaction(uint256 txId_)
        public
        view
        returns (
            uint256 txId,
            uint256 tokenId,
            uint256 amount,
            uint256 fromChain,
            uint256 toChain,
            address user,
            uint256 txBlockNo,
            uint256 currentBlockNo
        )
    {
        txId = txs[txId_].txId;
        tokenId = txs[txId_].tokenId;
        amount = txs[txId_].amount;
        fromChain = txs[txId_].fromChain;
        toChain = txs[txId_].toChain;
        user = txs[txId_].user;
        txBlockNo = txs[txId_].txBlockNo;
        currentBlockNo = block.number;
    }

    function getExecutingChainID() public view returns (uint256) {
        uint256 id;
        assembly {
            id := chainid()
        }
        return id;
    }

    /* ========== RESTRICTED FUNCTIONS ========== */

    function setBridgeReserve(uint256 bridgeReserve_) external onlyOwner {
        emit BridgeReserveSet(bridgeReserve, bridgeReserve_);

        bridgeReserve = bridgeReserve_;
    }

    function setToken(uint256 tokenId, address tokenAddress)
        external
        onlyOwner
    {
        tokens[tokenId] = tokenAddress;
    }

    function setNetworkID(uint256 network_) external onlyOwner {
        network = network_;
        delete sideContracts[network];
    }

    function setFee(uint256 tokenId, uint256 fee_) external onlyOwner {
        fee[tokenId] = fee_;
    }

    function setDeiAddress(address deiAddress_) external onlyOwner {
        deiAddress = deiAddress_;
    }

    function setMinReqSigs(uint256 minReqSigs_) external onlyOwner {
        minReqSigs = minReqSigs_;
    }

    function setSideContract(uint256 network_, address address_)
        external
        onlyOwner
    {
        require(network != network_, "Bridge: current network");
        sideContracts[network_] = address_;
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

    function pause() external onlyOwner {
        super._pause();
    }

    function unpase() external onlyOwner {
        super._unpause();
    }

    function withdrawFee(uint256 tokenId, address to) external onlyOwner {
        require(collectedFee[tokenId] > 0, "Bridge: No fee to collect");

        IERC20(tokens[tokenId]).pool_mint(to, collectedFee[tokenId]);
        collectedFee[tokenId] = 0;
    }

    function emergencyWithdrawETH(address to, uint256 amount)
        external
        onlyOwner
    {
        require(to != address(0));
        payable(to).transfer(amount);
    }

    function emergencyWithdrawERC20Tokens(
        address tokenAddr,
        address to,
        uint256 amount
    ) external onlyOwner {
        require(to != address(0));
        IERC20(tokenAddr).transfer(to, amount);
    }
}
