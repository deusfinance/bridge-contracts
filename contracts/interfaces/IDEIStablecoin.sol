pragma solidity >=0.8.0 <=0.9.0;

interface IDEIStablecoin {
	function global_collateral_ratio() external view returns (uint256);
}