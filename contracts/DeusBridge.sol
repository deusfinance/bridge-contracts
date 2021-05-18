// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./MuonV01.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

interface StandardToken {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
}

contract DeusBridge is Ownable{
    using SafeMath for uint256;
    using ECDSA for bytes32;

    // we assign a unique ID to each chain
    uint256 public network;
    mapping (uint256 => address) public sideContracts;
    address public muonContract;

    event Deposit(
        uint256 txId,
        uint256 tokenId,
        uint256 amount,
        uint256 indexed toChain,
        address indexed user
    );

    event Claim(
        address indexed user,
        uint256 amount, 
        uint256 indexed fromChain, 
        uint256 tokenId, 
        uint256 txId
    );

    // tokenId => tokenContractAddress
    mapping(uint256 => address) public tokens;

    struct TX{
        uint256 txId;
        uint256 tokenId;
        uint256 amount;
        uint256 fromChain;
        uint256 toChain;
        address user;
    }
    uint256 lastTxId = 0;

    mapping(uint256 => TX) public txs;
    mapping(address => mapping(uint256 => uint256[])) public userTxs;

    mapping(uint256 => mapping(uint256 => bool)) public claimedTxs;

    constructor(uint256 _network, address _muon){
        network = _network;
        muonContract = _muon;
    }

    function deposit(uint256 amount, uint256 toChain,
        uint256 tokenId) public returns (uint256){
        return depositFor(msg.sender, amount, toChain, tokenId);
    }

    function depositFor(address user,
        uint256 amount, uint256 toChain,
        uint256 tokenId
    ) public returns (uint256){
        require(toChain != network, "!selfDeposit");
        require(tokens[tokenId] != address(0), "!tokenId");

        StandardToken token = StandardToken(tokens[tokenId]);
        token.transferFrom(address(msg.sender), address(this), amount);

        uint256 txId = ++lastTxId;
        txs[txId] = TX({
            txId: txId,
            tokenId: tokenId,
            fromChain: network,
            toChain: toChain,
            amount: amount,
            user: user
        });
        userTxs[user][toChain].push(txId);
        emit Deposit(txId, tokenId, amount, toChain, user);

        return txId;
    }

    //TODO: add Muon signature
    function claim(address user,
        uint256 amount, uint256 fromChain, uint256 toChain,
        uint256 tokenId, uint256 txId, bytes[] calldata sigs) public{

        require(sideContracts[fromChain] != address(0), 'side contract not exist');
        require(toChain == network, "!network");
        require(sigs.length > 1, "!sigs");

        bytes32 hash = keccak256(abi.encodePacked(sideContracts[fromChain], user, amount, fromChain, toChain, tokenId, txId));
        hash = hash.toEthSignedMessageHash();

        MuonV01 muon = MuonV01(muonContract);
        bool isVerified = muon.verify(hash, sigs);

        require(isVerified, "sigs not verified");

        //TODO: shall we support more than one chain in one contract?
        require(!claimedTxs[fromChain][txId], "alreay claimed");
        require(tokens[tokenId] != address(0), "!tokenId");

        StandardToken token = StandardToken(tokens[tokenId]);

        //TODO: any fees?
        token.transfer(user, amount);
        claimedTxs[fromChain][txId] = true;
        emit Claim(user, amount, fromChain, tokenId, txId);
    }

    function pendingTxs(uint256 fromChain, uint256[] calldata ids) public view returns(
        bool[] memory unclaimedIds
    ){
        unclaimedIds = new bool[](ids.length);
        for(uint256 i=0; i < ids.length; i++){
            unclaimedIds[i] = claimedTxs[fromChain][ids[i]];
        }
    }

    function getUserTxs(address user, uint256 toChain) public view returns(
        uint256[] memory
    ){
        return userTxs[user][toChain];
    }

    function getTx(uint256 _txId) public view returns(
        uint256 txId,
        uint256 tokenId,
        uint256 amount,
        uint256 fromChain,
        uint256 toChain,
        address user
    ){
        txId = txs[_txId].txId;
        tokenId = txs[_txId].tokenId;
        amount = txs[_txId].amount;
        fromChain = txs[_txId].fromChain;
        toChain = txs[_txId].toChain;
        user = txs[_txId].user;
    }

    function ownerAddToken(
        uint256 tokenId, address tokenContract
    ) public onlyOwner{
        tokens[tokenId] = tokenContract;
    }

    function ownerSetNetworkID(
        uint256 _network
    ) public onlyOwner{
        network = _network;
        delete sideContracts[network];
    }

    function ownerSetSideContract(uint256 _network, address _addr) public onlyOwner{
        require (network != _network, '!current contract');
        sideContracts[_network] = _addr;
    }

    function emergencyWithdrawETH(uint256 amount, address addr) public onlyOwner{
        require(addr != address(0));
        payable(addr).transfer(amount);
    }

    function emergencyWithdrawERC20Tokens(address _tokenAddr, address _to, uint _amount) public onlyOwner {
        StandardToken(_tokenAddr).transfer(_to, _amount);
    }
}
