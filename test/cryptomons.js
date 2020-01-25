const Market = artifacts.require("Market");
const Cryptomon = artifacts.require("Cryptomon");

contract("Cryptomon test", async accounts => {
  let cryptomon;
  const minter = accounts[0];
  const receiver = accounts[1];

  beforeEach(async function() {
    cryptomon = await Cryptomon.deployed();
  });
  it("should be able to mint Cryptomons to account", async () => {
    const tx = await cryptomon.createCryptomon(receiver, "1", { from: minter });
    expect(tx.logs[0].event).to.equal("Transfer");
    expect(tx.logs[0].args.from).to.equal(
      "0x0000000000000000000000000000000000000000"
    );
    expect(tx.logs[0].args.to).to.equal(receiver);
    expect(tx.logs[1].event).to.equal("Minted");
    expect(tx.logs[1].args._toMarket).to.equal(false);
  });
  it("should be able to mint Cryptomons to market", async () => {
    const tx = await cryptomon.createCryptomon(Market.address, "1", {
      from: minter
    });
    expect(tx.logs[0].event).to.equal("Transfer");
    expect(tx.logs[0].args.from).to.equal(
      "0x0000000000000000000000000000000000000000"
    );
    expect(tx.logs[0].args.to).to.equal(Market.address);
    expect(tx.logs[1].event).to.equal("Minted");
    expect(tx.logs[1].args._toMarket).to.equal(true);
  });
});
