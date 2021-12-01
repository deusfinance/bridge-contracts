truffle deploy --network=bsc --muonAddress=0xE4F8d9A30936a6F8b17a73dC6fEb51a3BBABD51A &&
truffle deploy --network=fantom --muonAddress=0xE4F8d9A30936a6F8b17a73dC6fEb51a3BBABD51A &&
./node_modules/.bin/truffle run verify DeusBridge --network=bsc --debug &&
./node_modules/.bin/truffle run verify DeusBridge --network=fantom --debug
