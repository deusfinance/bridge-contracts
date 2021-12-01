pragma solidity >=0.8.0 <=0.9.0;

import "./IMuonV02.sol";

struct Transaction {
    uint txId;
    uint tokenId;
    uint amount;
    uint fromChain;
    uint toChain;
    address user;
    uint txBlockNo;
}

interface IDeusBridge {
	/* ========== STATE VARIABLES ========== */
	
    function lastTxId() external view returns (uint);
    function network() external view returns (uint);
    function minReqSigs() external view returns (uint);
    function scale() external view returns (uint);
    function bridgeReserve() external view returns (uint);
    function muonContract() external view returns (address);
    function deiAddress() external view returns (address);
    function mintable() external view returns (bool);
    function ETH_APP_ID() external view returns (uint8);
    function sideContracts(uint) external view returns (address);
    function tokens(uint) external view returns (address);
    function claimedTxs(uint, uint) external view returns (bool);
    function fee(uint) external view returns (uint);
    function collectedFee(uint) external view returns (uint);

	/* ========== PUBLIC FUNCTIONS ========== */
	function deposit(
		uint amount, 
		uint toChain,
		uint tokenId
	) external returns (uint txId);
	function depositFor(
		address user,
		uint amount, 
		uint toChain,
		uint tokenId
	) external returns (uint txId);
	function deposit(
		uint amount, 
		uint toChain,
		uint tokenId,
		uint referralCode
	) external returns (uint txId);
	function depositFor(
		address user,
		uint amount, 
		uint toChain,
		uint tokenId,
		uint referralCode
	) external returns (uint txId);
	function claim(
        address user,
        uint amount,
        uint fromChain,
        uint toChain,
        uint tokenId,
        uint currentBlockNo,
        uint txBlockNo,
        uint txId,
        bytes calldata _reqId,
        SchnorrSign[] calldata sigs
    ) external;

	/* ========== VIEWS ========== */
	function collatDollarBalance(uint collat_usd_price) external view returns (uint);
	function pendingTxs(
		uint fromChain, 
		uint[] calldata ids
	) external view returns (bool[] memory unclaimedIds);
	function getUserTxs(
		address user, 
		uint toChain
	) external view returns (uint[] memory);
	function getTransaction(uint txId_) external view returns (
		uint txId,
		uint tokenId,
		uint amount,
		uint fromChain,
		uint toChain,
		address user,
		uint txBlockNo,
		uint currentBlockNo
	);
	function getExecutingChainID() external view returns (uint);

	/* ========== RESTRICTED FUNCTIONS ========== */
	function setBridgeReserve(uint bridgeReserve_) external;
	function setToken(uint tokenId, address tokenAddress) external;
	function setNetworkID(uint network_) external;
	function setFee(uint tokenId, uint fee_) external;
	function setDeiAddress(address deiAddress_) external;
	function setMinReqSigs(uint minReqSigs_) external;
	function setSideContract(uint network_, address address_) external;
	function setMintable(bool mintable_) external;
	function setEthAppId(uint8 ethAppId_) external;
	function setMuonContract(address muonContract_) external;
	function pause() external;
	function unpase() external;
	function withdrawFee(uint tokenId, address to) external;
	function emergencyWithdrawETH(address to, uint amount) external;
	function emergencyWithdrawERC20Tokens(address tokenAddr, address to, uint amount) external;
}
