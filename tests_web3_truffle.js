var Web3 = require("web3");
const fs = require("fs");

var provider = new Web3.providers.HttpProvider("http://127.0.0.1:9545/");
var contract = require("@truffle/contract");

var account_one = "0x8513A920036D477183832C8A63628F561C5757A2";
var account_two = "0x3A03C9DBE5913812111A2F5B6DA1F22F9177FE36";

fs.readFile("build/contracts/Cryptomon.json", (err, data) => {
  if (err) throw err;
  let jdata = JSON.parse(data);

  var MyContract = contract(jdata);

  MyContract.defaults({
    from: account_one
  });

  MyContract.setProvider(provider);

  var contractInst;

  MyContract.deployed()
    .then(function(instance) {
      contractInst = instance;

      return contractInst.createCryptomon(account_two, "randomjson", {
        from: account_one
      });
    })
    .then(function(result) {
      tokenId = result.logs[0].args.tokenId.toNumber();
      console.log("Created token with id ", tokenId);
      return tokenId;
    })
    .then(function(tokenId) {
      return contractInst.tokenURI.call(tokenId, {
        from: account_one
      });
    })
    .then(function(result) {
      console.log("Uri of this token : ", result);
    })
    .then(function() {
      return contractInst.totalSupply.call();
    })
    .then(result => {
      total = result.toNumber();
      console.log("Total of emmited NFT : ", total);
      return total;
    })
    .then(total => {
      for (i = 0; i < total; i++) {
        contractInst.tokenByIndex
          .call(i)
          .then(result => console.log("Token id: ", result.toNumber()));
      }
    })
    .catch(function(e) {
      console.error(e.message); // "oh, no!"
    });
});
