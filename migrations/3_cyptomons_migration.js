const Cryptomon = artifacts.require("Cryptomon");
const Market = artifacts.require("Market");
const fs = require("fs").promises;
const path = require("path");

var minter_address = "";
var marketplace_contract = Market.address;

module.exports = async function(deployer, network, accounts) {
  minter_address = accounts[0];

  // deploy the token contract
  await deployer.deploy(Cryptomon, marketplace_contract, {
    from: minter_address
  });
  const cryptomonC = await Cryptomon.deployed();

  const market = await Market.deployed();

  await market.setCMContract(cryptomonC.address, { from: accounts[0] });

  try {
    // mint crypto to user 1
    await mint_cryptomons(
      cryptomonC,
      minter_address,
      minter_address,
      "initial_cryptomons.json"
    );
    // mint crypto to market
    await mint_one_of_each(cryptomonC, minter_address, marketplace_contract);

    // mint to p2
    await mint_cryptomons(
      cryptomonC,
      minter_address,
      accounts[1],
      "initial_cryptomons.json"
    );
  } catch (error) {
    console.log(error);
  }
};

async function mint_cryptomons(instance, from, to, file_name) {
  const data = await fs.readFile(path.resolve(__dirname, file_name));
  // parse it
  let jdata = JSON.parse(data);
  console.log();
  baseURI = jdata.baseURI;

  // an array of promises for creation of all cryptomons
  const promises = [];

  jdata.tokens.forEach(token => {
    console.log(
      `Minting ${token.number} tokens with metadata URI ${baseURI +
        token.uri_suffix} from address ${from} to contract ${to}`
    );
    // For each token, we loop the number of times it must be minted
    for (i = 0; i < token.number; i++) {
      // we add a new promise from the minting of a new token to the market
      promises.push(
        instance.createCryptomon(to, baseURI + token.uri_suffix, {
          from: from
        })
      );
    }
  });
  // waiting for all promises to end
  await Promise.all(promises);
}

async function mint_one_of_each(instance, from, to) {
  const promises = [];
  const baseURI = "https://morning-springs-53559.herokuapp.com/cryptomon/meta/";
  for (i = 141; i <= 151; i++) {
    promises.push(
      instance.createCryptomon(to, baseURI + i.toString(), {
        from: from
      })
    );
  }
}
