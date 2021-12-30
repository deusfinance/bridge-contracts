// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <=0.9.0;

interface IERC20 {
	function transfer(address recipient, uint256 amount) external;
	function transferFrom(address sender, address recipient, uint256 amount) external;
	function pool_burn_from(address b_address, uint256 b_amount) external;
	function pool_mint(address m_address, uint256 m_amount) external;
}
