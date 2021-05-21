// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract MuonV01 is Ownable {
    using ECDSA for bytes32;

    mapping(address => bool) public signers;
    
    function verify(bytes32 hash, bytes[] calldata sigs) public view returns (bool) {
        uint i;
        address signer;
        for(i=0 ; i<sigs.length ; i++){
            signer = hash.recover(sigs[i]);
            // require(attualSigner == signer, "Signature not confirmed");
            if(signers[signer] != true)
                return false;
        }
        return sigs.length > 0;
    }

    function ownerAddSigner(address _signer) public onlyOwner {
        signers[_signer] = true;
    }

    function ownerRemoveSigner(address _signer) public onlyOwner {
        delete signers[_signer];
    }
}
