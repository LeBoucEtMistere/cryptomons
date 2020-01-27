const Market = artifacts.require("Market");
const Cryptomon = artifacts.require("Cryptomon");

contract("Market test", async accounts => {
  let market;
  let cryptomon;
  const minter = accounts[0];
  const receiver = accounts[1];

  beforeEach(async function() {
    market = await Market.deployed();
    cryptomon = await Cryptomon.deployed();
  });
  it("should have valid address for CM contract", async () => {
    const cmc = await market.getCMContract.call({ from: minter });
    expect(cmc).to.equal(cryptomon.address);
  });

  it("should let user list a valid token on market", async () => {
    const tokenId = 1;
    const value = 10000;
    var prevSoldTokens = await market.getListedTokens.call({ from: minter });
    prevSoldTokens = prevSoldTokens.map(x => parseInt(x, 10));
    await cryptomon.approve(market.address, tokenId, { from: minter });
    const tx = await market.listToken(tokenId, value);
    var soldTokens = await market.getListedTokens.call({ from: minter });
    soldTokens = soldTokens.map(x => parseInt(x, 10));
    var diffTokens = [];
    soldTokens.forEach(token => {
      if (!prevSoldTokens.includes(token)) diffTokens.push(token);
    });

    expect(diffTokens).to.deep.equal([1]);
    expect(tx.logs[0].event).to.equal("Listed");
    expect(tx.logs[0].args._by).to.equal(minter);
    expect(parseInt(tx.logs[0].args._value, 10)).to.equal(value);
    expect(parseInt(tx.logs[0].args._tokenId, 10)).to.equal(tokenId);
  });
  it("should let user unlist a listed token on market", async () => {
    const tokenId = 1;
    const value = 10000;
    var prevSoldTokens = await market.getListedTokens.call({ from: minter });
    prevSoldTokens = prevSoldTokens.map(x => parseInt(x, 10));
    await cryptomon.approve(market.address, tokenId, { from: minter });
    await market.listToken(tokenId, value);
    const tx2 = await market.unlistToken(tokenId);
    var soldTokens = await market.getListedTokens.call({ from: minter });
    soldTokens = soldTokens.map(x => parseInt(x, 10));
    var diffTokens = [];
    soldTokens.forEach(token => {
      if (!prevSoldTokens.includes(token)) diffTokens.push(token);
    });

    expect(diffTokens).to.deep.equal([]);
    expect(tx2.logs[0].event).to.equal("Unlisted");
    expect(tx2.logs[0].args._by).to.equal(minter);
    expect(parseInt(tx2.logs[0].args._tokenId, 10)).to.equal(tokenId);
  });

  it("should error on user trying to unlist a non listed token on market", async () => {
    const tokenId = 1;
    try {
      await market.unlistToken(tokenId);
    } catch (error) {
      expect(error.message).to.include(
        "This token is not listed on the market"
      );
    }
  });

  it("should error when trying to unlist a token you do not own on the market", async () => {
    const tokenId = 1;
    const value = 100000;
    await cryptomon.approve(market.address, tokenId, { from: minter });
    await market.listToken(tokenId, value);
    try {
      await market.unlistToken(tokenId, { from: receiver });
    } catch (error) {
      expect(error.message).to.include(
        "Trying to unlist a token you do not own"
      );
    }
  });

  it("should not let user list a token that market is not approved on", async () => {
    try {
      await market.listToken(1, 10000, { from: minter });
    } catch (error) {
      expect(error.message).to.include(
        "The Market is not approved for this token"
      );
    }
  });

  it("should not let user list a token they do not own", async () => {
    const tokenId = 1;
    await cryptomon.approve(market.address, tokenId, { from: minter });
    try {
      await market.listToken(1, 10000, { from: receiver });
    } catch (error) {
      expect(error.message).to.include("Trying to sell a token you do not own");
    }
  });

  it("should let user buy a valid token", async () => {
    const tokenId = 1;
    const value = 10000000000000;

    // save balances
    const seller_balance = await web3.eth.getBalance(minter);
    const buyer_balance = await web3.eth.getBalance(receiver);

    const tx1 = await cryptomon.approve(market.address, tokenId, {
      from: minter
    });
    const tx2 = await market.listToken(tokenId, value, { from: minter });
    const tx3 = await market.buyToken.sendTransaction(tokenId, {
      value: value,
      from: receiver
    });

    // new balances
    const new_seller_balance = await web3.eth.getBalance(minter);
    const new_buyer_balance = await web3.eth.getBalance(receiver);

    const gasPrice = await web3.eth.getGasPrice();
    const seller_diff =
      -gasPrice *
      (parseInt(tx1.receipt.cumulativeGasUsed, 10) +
        parseInt(tx2.receipt.cumulativeGasUsed, 10));
    const buyer_diff =
      -1 * (value + gasPrice * parseInt(tx3.receipt.cumulativeGasUsed, 10));

    // check for balances evolution
    // expect(new_seller_balance - seller_balance).to.be.lte(seller_diff);
    // expect(new_buyer_balance - buyer_balance).to.be.lte(buyer_diff);

    // check for event emission
    expect(tx3.logs[0].event).to.equal("Sold");
    expect(tx3.logs[0].args._from).to.equal(minter);
    expect(tx3.logs[0].args._to).to.equal(receiver);
    expect(parseInt(tx3.logs[0].args._value, 10)).to.equal(value);
    expect(parseInt(tx3.logs[0].args._tokenId, 10)).to.equal(tokenId);
  });

  it("should error when user try to buy a token that the owner approved for market but then transfered elsewhere", async () => {
    const tokenId = 2;
    const value = 10000;
    await cryptomon.approve(market.address, tokenId, { from: minter });
    await market.listToken(tokenId, value);
    await cryptomon.safeTransferFrom(minter, receiver, tokenId, {
      from: minter
    });
    try {
      await market.buyToken.sendTransaction(tokenId, {
        value: value,
        from: receiver
      });
    } catch (error) {
      expect(error.message).to.include(
        "ERC721: transfer caller is not owner nor approved"
      );
    }
  });

  it("should not let user buy token without paying enough", async () => {
    const tokenId = 3;
    const price = 10000;
    const value = 100;
    await cryptomon.approve(market.address, tokenId, { from: minter });
    await market.listToken(tokenId, price);
    try {
      await market.buyToken.sendTransaction(tokenId, {
        value: value,
        from: receiver
      });
    } catch (error) {
      expect(error.message).to.include("money < price");
    }
  });

  it("should not let user buy unlisted token", async () => {
    const tokenId = 4;
    const value = 10000;
    const balance = receiver.balance;
    await cryptomon.approve(market.address, tokenId, { from: minter });
    try {
      await market.buyToken.sendTransaction(tokenId, {
        value: value,
        from: receiver
      });
    } catch (error) {
      expect(error.message).to.include("This token is not listed for sale");
    }
    expect(receiver.balance).to.eql(balance);
  });
  it("should let user retrieve price of a listed token", async () => {
    const tokenId = 4;
    const value = 10000;
    await cryptomon.approve(market.address, tokenId, { from: minter });
    await market.listToken(tokenId, value);
    const tokenPrice = await market.getTokenPrice(tokenId, {
      from: receiver
    });
    expect(parseInt(tokenPrice, 10)).to.equal(value);
  });
  it("should error on user retrieving price of an unlisted token", async () => {
    const tokenId = 4;
    try {
      await market.getTokenPrice(tokenId, {
        from: receiver
      });
    } catch (error) {
      expect(error.message).to.include("Token not listed for sale");
    }
  });
});
