
const Muon = artifacts.require("MuonV01");
const ERT = artifacts.require('ERT');
const DEAToken = artifacts.require('DEAToken');
const SampleApp = artifacts.require("SampleApp");
const DeusBridge = artifacts.require("DeusBridge");
const truffleAssert = require('truffle-assertions');
const muonNode = require('../test-utils/muon-node')

ADDR_0 = '0xf0A6FBe0e3E016bE50aec2d2Ff7B2aA3008Ce1Ce'
PKEY_0 = '80f895b658158c89ed058fc8cd5d0ffc3bed60563b7395e97e9a36d795e98f50'

ADDR_1 = '0x398502Cf428866aC3Aca407610e6EFF70a62565A'
PKEY_1 = '5dedb935b2c49111db884aad29dead845f86c2ac96d2a74a3e99f70159c7f233'

MUON_NODE_1 = '0x06A85356DCb5b307096726FB86A78c59D38e08ee'
MUON_NODE_2 = '0x4513218Ce2e31004348Fd374856152e1a026283C'
MUON_NODE_3 = '0xe4f507b6D5492491f4B57f0f235B158C4C862fea'

const ETH = 1, BSC = 2, FTM = 3, TOKEN_ID=1;

contract("MuonV01", (accounts) => {
	let muon, sampleApp, deaToken;
	let ethBridge, bscBridge, ftmBridge;
    before(async () => {
        muon = await Muon.deployed();
        await muon.ownerAddSigner(ADDR_0)
        await muon.ownerAddSigner(MUON_NODE_1)
        await muon.ownerAddSigner(MUON_NODE_2)
        await muon.ownerAddSigner(MUON_NODE_3)

        // deploy SampleApp contract
        sampleApp = await SampleApp.new(muon.address)

        // deploy sample token
        deaToken = await DEAToken.new({from: accounts[0]});
        const MINTER_ROLE = await deaToken.MINTER_ROLE.call();
        await deaToken.grantRole(MINTER_ROLE, accounts[0])
        await deaToken.mint(accounts[1], web3.utils.toWei('25000'))
        await deaToken.revokeRole(MINTER_ROLE, accounts[0])

        // deploy bridge of eth/bsc/fantom
        ethBridge = await DeusBridge.new(muon.address, false, {from: accounts[0]});
        bscBridge = await DeusBridge.new(muon.address, true,  {from: accounts[0]});
        ftmBridge = await DeusBridge.new(muon.address, true,  {from: accounts[0]});

        await ethBridge.ownerSetMintable(true)
        await bscBridge.ownerSetMintable(true)
        await ftmBridge.ownerSetMintable(true)

        //for test we set this network ID
        await ethBridge.ownerSetNetworkID(ETH);
        await bscBridge.ownerSetNetworkID(BSC);
        await ftmBridge.ownerSetNetworkID(FTM);

        // set side contracts
        await ethBridge.ownerSetSideContract(BSC, bscBridge.address);
        await ethBridge.ownerSetSideContract(FTM, ftmBridge.address);
        await bscBridge.ownerSetSideContract(ETH, ethBridge.address);
        await bscBridge.ownerSetSideContract(FTM, ftmBridge.address);
        await ftmBridge.ownerSetSideContract(ETH, ethBridge.address);
        await ftmBridge.ownerSetSideContract(BSC, bscBridge.address);

        // add token to bridges
        await ethBridge.ownerAddToken(TOKEN_ID, deaToken.address)
        await bscBridge.ownerAddToken(TOKEN_ID, deaToken.address)
        await ftmBridge.ownerAddToken(TOKEN_ID, deaToken.address)

        console.log({
        	ethBridge: ethBridge.address,
        	bscBridge: bscBridge.address,
        	ftmBridge: ftmBridge.address,
        })
    });

    describe('Check Muon signers', async () => {
    	it("Signers add test", async () => {
	        let isAccount0 = await muon.signers.call(ADDR_0)
	        let isAccount1 = await muon.signers.call(ADDR_1)

	        assert(isAccount0, `${ADDR_0} should be signer and its not.`)
	        assert(!isAccount1, `${ADDR_1} should not be signer and it is signer.`)
    	})
    })

    describe('Validate signatures', async () => {
    	it("Check valid signers signature", async () => {
    		let requestId = 123, timestamp=45, price=12;

	        let hash = web3.utils.soliditySha3(
		        { type: 'uint256', value: requestId },
		        { type: 'uint256', value: timestamp},
		        { type: 'uint256', value: price}
		    );

	        let {signature: sig} = await web3.eth.accounts.sign(hash, PKEY_0)

	        let actionResult1 = await sampleApp.action(requestId, timestamp, price, sig)

            truffleAssert.eventEmitted(actionResult1, 'Action', (ev) => {
                return (ev.requestId.eq(web3.utils.toBN(requestId)));
            });
    	})

    	it("Check invalid signers signature", async () => {
    		let requestId = 123, timestamp=45, price=12;

	        let hash = web3.utils.soliditySha3(
		        { type: 'uint256', value: requestId },
		        { type: 'uint256', value: timestamp},
		        { type: 'uint256', value: price}
		    );

	        let {signature: sig} = await web3.eth.accounts.sign(hash, PKEY_1)

	        try{
	        	let actionResult1 = await sampleApp.action(requestId, timestamp, price, sig)
	    	}
	    	catch(error){
                const sigInvalid = error.message.search('signature not valid') >= 0;
                assert(sigInvalid, `App should throw the error "signature not valid"`)
	    	}
    	})
    })

    describe('Bridge test', async () => {

    	it("deposit/claim", async () => {
            let depositAmount = web3.utils.toWei('500');
            const MINTER_ROLE = await deaToken.MINTER_ROLE.call();
            const BURNER_ROLE = await deaToken.BURNER_ROLE.call();

    		await deaToken.approve(ethBridge.address, depositAmount, {from: accounts[1]});

            let txDeposit 
            try{
                txDeposit = await ethBridge.deposit(depositAmount, BSC, TOKEN_ID, {from: accounts[1]});
                assert(false, `Burn occured but it not permitted`)
            }
            catch(error){
                const missingRole = error.message.search('is missing role') >= 0;
                assert(missingRole, `App should throw the error "is missing role of burn"`)
            }

            await deaToken.grantRole(BURNER_ROLE, ethBridge.address)
            await deaToken.grantRole(MINTER_ROLE, bscBridge.address)
            txDeposit = await ethBridge.deposit(depositAmount, BSC, TOKEN_ID, {from: accounts[1]});
	    	
	    	truffleAssert.eventEmitted(txDeposit, 'Deposit', (ev) => {
	            return (
	            	ev.user === accounts[1]
	            	&& ev.toChain.eq(web3.utils.toBN(BSC))
	            	&& !!ev.txId
	            );
	        });

	    	let txId = txDeposit.logs.find(log => (log.event === 'Deposit')).args.txId.toString();
	        let nodesSigResults = await muonNode.ethCallContract(ethBridge.address, 'getTx', [txId], ethBridge.abi);
	        let sigs = nodesSigResults.result.signatures.map(({signature}) => signature)
            console.log({sigs});

	    	let txClaim = await bscBridge.claim(accounts[1], depositAmount, ETH, BSC, TOKEN_ID, txId, sigs, {from: accounts[1]});

            truffleAssert.eventEmitted(txClaim, 'Claim', (ev) => {
                return (
                    ev.user == accounts[1] 
                    && ev.amount.toString() == depositAmount.toString()
                    && ev.fromChain.eq(web3.utils.toBN(ETH))
                );
            });
    	})
    })
})