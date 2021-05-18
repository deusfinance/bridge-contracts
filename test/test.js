const ERT = artifacts.require('ERT');
const DeusBridge = artifacts.require("DeusBridge");
const truffleAssert = require('truffle-assertions');
let muonNode = require('../test-utils/muon-node')

const toWei = (number) => number * Math.pow(10, 6);
const fromWei = (x) => x/1e6;
const addr0 = "0x0000000000000000000000000000000000000000";
const bytes0 = "0x0000000000000000000000000000000000000000000000000000000000000000";

contract("DeusBridge", (accounts) => {
    let deusBridge;
    const NETWORK_ID = 180;

    before(async () => {
        deusBridge = await DeusBridge.deployed();
    });

    describe("Testing networkID.", async () => {
        before("setting networkID using accounts[0]", async () => {
            await deusBridge.ownerSetNetworkID(NETWORK_ID);
        });

        it("can fetch the networkID id", async () => {
            const networkID = await deusBridge.network.call();
            assert.equal(networkID, NETWORK_ID, "The networkID should be 1.");
        });
    });

    describe("Testing tokenID", async () => {
        it("should not able to deposit unknown tokenID", async () => {
            try{
                await deusBridge.deposit(12, 2, 55, {from: accounts[0]});
                // assert.equal(networkID, 180, "The networkID should be 1.");
            }
            catch (error){
                const unknownToken = error.message.search('!tokenId') >= 0;
                assert(unknownToken, "deposit not allowed for unknown tokenId")
                return;
            }
        });

        it("Non owner address not allowed to add token", async () => {
            try{
                await deusBridge.ownerAddToken(1, addr0, {from: accounts[1]});
            }
            catch (error){
                const unknownOwner = error.message.search('caller is not the owner') >= 0;
                assert(unknownOwner, "adding token, not allowed for unknown owner")
                // return;
            }
        });
    })

    describe("Testing deposit/claim", async () => {
        
        const tokenID = 1, toChain = NETWORK_ID;
        let token;
        
        before("", async () => {
            token = await ERT.new({from: accounts[0]})
            await deusBridge.ownerAddToken(tokenID, token.address);
            await token.mint(accounts[1], 250)
        })

        it("deposit/claim new token", async () => {
            await token.approve(deusBridge.address, 100, {from: accounts[1]});
            let txDeposit = await deusBridge.deposit(100, toChain, tokenID, {from: accounts[1]})

            truffleAssert.eventEmitted(txDeposit, 'Deposit', (ev) => {
                return (
                    ev.user == accounts[1] 
                    && ev.amount.eq(web3.utils.toBN(100))
                    && ev.toChain.eq(web3.utils.toBN(toChain))
                );
            });

            let tokenBalance = await token.balanceOf(accounts[1])
            assert(tokenBalance == 150, `user balance should be 150 instead of ${tokenBalance}`)
        })
    })
});