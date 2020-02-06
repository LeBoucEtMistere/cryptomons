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
    const tx = await cryptomon.createCryptomon(receiver, "1", 0, {
      from: minter
    });
    expect(tx.logs[0].event).to.equal("Transfer");
    expect(tx.logs[0].args.from).to.equal(
      "0x0000000000000000000000000000000000000000"
    );
    expect(tx.logs[0].args.to).to.equal(receiver);
    expect(tx.logs[1].event).to.equal("Minted");
    expect(tx.logs[1].args._toMarket).to.equal(false);
  });
  it("should be able to mint Cryptomons to market", async () => {
    const tx = await cryptomon.createCryptomon(
      Market.address,
      "1",
      10000000000000,
      {
        from: minter
      }
    );
    expect(tx.logs[0].event).to.equal("Transfer");
    expect(tx.logs[0].args.from).to.equal(
      "0x0000000000000000000000000000000000000000"
    );
    expect(tx.logs[0].args.to).to.equal(Market.address);
    expect(tx.logs[1].event).to.equal("Minted");
    expect(tx.logs[1].args._toMarket).to.equal(true);
  });
  it("should be able to breed tokens", async () => {
    const tx = await cryptomon.breed(1, 2, {
      from: minter
    });
    expect(tx.logs[0].event).to.equal("Breeding");
    expect(parseInt(tx.logs[0].args.parent1, 10)).to.equal(1);
    expect(parseInt(tx.logs[0].args.parent2, 10)).to.equal(2);
  });
  it("should be able to fetch breeding tokens", async () => {
    var prevBreedingTokens = await cryptomon.getBreedingTokens.call({
      from: minter
    });
    prevBreedingTokens = prevBreedingTokens.map(x => parseInt(x, 10));
    await cryptomon.breed(3, 4, {
      from: minter
    });
    var BreedingTokens = await cryptomon.getBreedingTokens.call({
      from: minter
    });
    BreedingTokens = BreedingTokens.map(x => parseInt(x, 10));
    var diffTokens = [];
    BreedingTokens.forEach(token => {
      if (!prevBreedingTokens.includes(token)) diffTokens.push(token);
    });
    expect(diffTokens).to.eql([3, 4]);
  });
  it("should be able to know if still breeding", async () => {
    await cryptomon.breed(5, 6, {
      from: minter
    });
    const hasHatched = await cryptomon.hasHatched.call(5, 6, { from: minter });
    expect(hasHatched).to.be.false;
  });
  it("should be able to interrupt a breeding", async () => {
    await cryptomon.breed(7, 8, {
      from: minter
    });
    const tx = await cryptomon.interruptBreeding(7, { from: minter });
    expect(tx.logs[0].event).to.equal("Interrupted");
    expect(parseInt(tx.logs[0].args.parent1, 10)).to.equal(7);
    expect(parseInt(tx.logs[0].args.parent2, 10)).to.equal(8);
    expect(tx.logs[0].args.by).to.equal(minter);
  });
});
