// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

interface StakedToken {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
}

contract DeusBridge is Ownable{
    using SafeMath for uint256;

    // we assign a unique ID to each chain
    uint256 public network;

    // tokenId => tokenContractAddress
    mapping(uint256 => address) public tokens;

    struct TX{
        uint256 txId;
        uint256 tokenId;
        uint256 amount;
        uint256 toChain;
        address user;
    }
    uint256 lastTxId = 0;

    mapping(uint256 => TX) public txs;
    mapping(address => uint256[]) userTxs;

    mapping(uint256 => bool) claimedTxs;

    constructor(
        uint256 _network
    ){
        network = _network;
    }

    function deposit(uint256 amount, uint256 toChain,
        uint256 tokenId) public {
        depositFor(msg.sender, amount, toChain, tokenId);
    }

    function depositFor(address user,
        uint256 amount, uint256 toChain,
        uint256 tokenId
    ) public {
        require(tokens[tokenId] != address(0), "!tokenId");

        StakedToken token = StakedToken(tokens[tokenId]);
        token.transferFrom(address(msg.sender), address(this), amount);

        uint256 txId = ++lastTxId;
        txs[lastTxId] = TX({
            txId: txId,
            tokenId: tokenId,
            toChain: toChain,
            amount: amount,
            user: user
        });
        userTxs[user].push(txId);
    }

    //TODO: add Muon signature
    function claim(address user,
        uint256 amount, uint256 toChain,
        uint256 tokenId, uint256 txId) public{

        require(toChain == network, "!network");

        //TODO: shall we support more than one chain in one contract?
        require(!claimedTxs[txId], "alreay claimed");
        require(tokens[tokenId] != address(0), "!tokenId");

        StakedToken token = StakedToken(tokens[tokenId]);

        //TODO: any fees?
        token.transfer(user, amount);
        claimedTxs[txId] = true;
    }

    function pendingTxs(uint256[] calldata ids) public view returns(
        bool[] memory unclaimedIds
    ){
        unclaimedIds = new bool[](ids.length);
        for(uint256 i=0; i < ids.length; i++){
            unclaimedIds[i] = claimedTxs[ids[i]];
        }
    }

    function ownerAddToken(
        uint256 tokenId, address tokenContract
    ) public onlyOwner{
        tokens[tokenId] = tokenContract;
    }

    function emergencyWithdrawETH(uint256 amount, address addr) public onlyOwner{
        require(addr != address(0));
        payable(addr).transfer(amount);
    }

    function emergencyWithdrawERC20Tokens(address _tokenAddr, address _to, uint _amount) public onlyOwner {
        StandardToken(_tokenAddr).transfer(_to, _amount);
    }
}
