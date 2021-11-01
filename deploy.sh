truffle deploy --network=rinkeby --muonAddress=0x4b3a3D16b6F54938bC1216b846E24cBdF9A221cB &&
truffle deploy --network=bsctest --muonAddress=0xFC9683a4256f892F2a848d22BfaCAb0c6d95D955 &&
./node_modules/.bin/truffle run verify DeusBridge --network=rinkeby --debug &&
./node_modules/.bin/truffle run verify DeusBridge --network=bsctest --debug
