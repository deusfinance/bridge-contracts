// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;
import './MuonV01.sol';
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract SampleApp {
    using ECDSA for bytes32;
    
    address muon;

    event Action(uint256 requestId, uint256 timestamp, uint256 price);
    
    constructor (address _muon) public {
        muon = _muon;
    }
    
    function action(uint256 requestId, uint256 timestamp, uint256 price, bytes calldata sig) external {
        bytes32 hash = keccak256(abi.encodePacked(requestId, timestamp, price));
        hash = hash.toEthSignedMessageHash();

        MuonV01 m = MuonV01(muon);
        bytes[] memory sigList = new bytes[](1);
        sigList[0] = sig;
        bool isValid = m.verify(hash, sigList);
        require(isValid, "signature not valid");

        emit Action(requestId, timestamp, price);
    }
}
