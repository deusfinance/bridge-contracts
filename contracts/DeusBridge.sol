// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./IMuonV02.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

interface IERC20 {
	function transfer(address recipient, uint256 amount) external;
	function transferFrom(address sender, address recipient, uint256 amount) external;
	function mint(address reveiver, uint256 amount) external;
	function burn(address sender, uint256 amount) external;
	function pool_burn_from(address b_address, uint256 b_amount) external;
	function pool_mint(address m_address, uint256 m_amount) external;
}

contract DeusBridge is Ownable {
	using ECDSA for bytes32;

	struct TX{
		uint256 txId;
		uint256 tokenId;
		uint256 amount;
		uint256 fromChain;
		uint256 toChain;
		address user;
	}


	uint256 public lastTxId = 0;
	uint256 public network;
	address public muonContract;
	bool    public mintable;
	uint8   public ETH_APP_ID = 2;
	// we assign a unique ID to each chain (default is CHAIN-ID)
	mapping (uint256 => address) public sideContracts;
	// tokenId => tokenContractAddress
	mapping(uint256 => address)  public tokens;
	mapping(uint256 => TX)       public txs;
	mapping(address => mapping(uint256 => uint256[])) public userTxs;
	mapping(uint256 => mapping(uint256 => bool))      public claimedTxs;

	event Deposit(
		address indexed user,
		uint256 tokenId,
		uint256 amount,
		uint256 indexed toChain,
		uint256 txId
	);

	event Claim(
		address indexed user,
		uint256 tokenId, 
		uint256 amount, 
		uint256 indexed fromChain, 
		uint256 txId
	);

	constructor(address _muon, bool _mintable) {
		network = getExecutingChainID();
		mintable = _mintable;
		muonContract = _muon;
	}

	function deposit(
		uint256 amount, 
		uint256 toChain,
		uint256 tokenId
	) external returns (uint256) {
		return depositFor(msg.sender, amount, toChain, tokenId);
	}

	function depositFor(
		address user,
		uint256 amount,
		uint256 toChain,
		uint256 tokenId
	) public returns (uint256 txId) {
		require(sideContracts[toChain] != address(0), "Bridge: unknown toChain");
		require(toChain != network, "Bridge: selfDeposit");
		require(tokens[tokenId] != address(0), "Bridge: unknown tokenId");

		IERC20 token = IERC20(tokens[tokenId]);
		if (mintable) {
			token.pool_burn_from(msg.sender, amount);
		} else {
			token.transferFrom(msg.sender, address(this), amount);
		}

		txId = ++lastTxId;
		txs[txId] = TX({
			txId: txId,
			tokenId: tokenId,
			fromChain: network,
			toChain: toChain,
			amount: amount,
			user: user
		});
		userTxs[user][toChain].push(txId);

		emit Deposit(user, tokenId, amount, toChain, txId);
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
	) public {
		require(sideContracts[fromChain] != address(0), 'Bridge: source contract not exist');
		require(toChain == network, "Bridge: toChain should equal network");
		require(sigs.length > 0, "Bridge: sigs is empty");

		bytes32 hash = keccak256(
			abi.encodePacked(
				abi.encodePacked(sideContracts[fromChain], txId, tokenId, amount),
				abi.encodePacked(fromChain, toChain, user, ETH_APP_ID)
			)
		);

		IMuonV02 muon = IMuonV02(muonContract);
		// NOTE: check casting hash to uint
		require(muon.verify(_reqId, uint256(hash), sigs), "Bridge: not verified");

		require(!claimedTxs[fromChain][txId], "Bridge: already claimed");
		require(tokens[tokenId] != address(0), "Bridge: unknown tokenId");

		IERC20 token = IERC20(tokens[tokenId]);
		if (mintable) {
			token.pool_mint(user, amount);
		} else { 
			token.transfer(user, amount);
		}

		claimedTxs[fromChain][txId] = true;
		emit Claim(user, tokenId, amount, fromChain, txId);
	}

	function pendingTxs(
		uint256 fromChain, 
		uint256[] calldata ids
	) public view returns (bool[] memory unclaimedIds) {
		unclaimedIds = new bool[](ids.length);
		for(uint256 i=0; i < ids.length; i++){
			unclaimedIds[i] = claimedTxs[fromChain][ids[i]];
		}
	}

	function getUserTxs(
		address user, 
		uint256 toChain
	) public view returns (uint256[] memory) {
		return userTxs[user][toChain];
	}

	// NOTE: ask from reza
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
		uint256 tokenId, 
		address tokenAddress
	) public onlyOwner {
		tokens[tokenId] = tokenAddress;
	}

	function getExecutingChainID() public view returns (uint256) {
		uint256 id;
		assembly {
			id := chainid()
		}
		return id;
	}

	// NOTE: double check it
	function ownerSetNetworkID(
		uint256 _network
	) public onlyOwner {
		network = _network;
		delete sideContracts[network];
	}

	function ownerSetSideContract(uint256 _network, address _addr) public onlyOwner {
		require (network != _network, 'Bridge: current network');
		sideContracts[_network] = _addr;
	}

	function ownerSetMintable(bool _mintable) public onlyOwner {
		mintable = _mintable;
	}

	function emergencyWithdrawETH(uint256 amount, address addr) external onlyOwner {
		require(addr != address(0));
		payable(addr).transfer(amount);
	}

	function emergencyWithdrawERC20Tokens(address _tokenAddr, address _to, uint _amount) external onlyOwner {
		IERC20(_tokenAddr).transfer(_to, _amount);
	}
}
