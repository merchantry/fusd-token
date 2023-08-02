const assert = require('assert');
const contracts = require('../compile');
const { deploy, getAccounts } = require('../utils/useWeb3');
const { useMethodsOn, useMethodOn } = require('../utils/contracts');

const tokenContract = contracts['FUSDToken.sol'].FUSDToken;

describe('FUSDToken tests', () => {
  let accounts, FUSDToken;

  beforeEach(async () => {
    accounts = await getAccounts();
    FUSDToken = await deploy(tokenContract, [], accounts[0]);
  });

  describe('FUSDToken', () => {
    it('deploys successfully', () => {
      assert.ok(FUSDToken.options.address);
    });
  });

  describe('FlaggingMinters', () => {
    it('adds owner initially to mint', () => {
      const owner = accounts[0];

      return useMethodOn(FUSDToken, {
        // Owner should be a minter after deployment
        method: 'isMinter',
        args: [owner],
        onReturn: (isMinter) => {
          assert.ok(isMinter);
        },
      });
    });

    it('allows owner to flag minters', () =>
      useMethodsOn(FUSDToken, [
        {
          // We first check that the account is not a minter
          method: 'isMinter',
          args: [accounts[1]],
          onReturn: (isMinter) => {
            assert.ok(!isMinter);
          },
        },
        {
          // Owner flags the account as a minter
          method: 'setIsMinter',
          args: [accounts[1], true],
          account: accounts[0],
        },
        {
          // We check that the account is now a minter
          method: 'isMinter',
          args: [accounts[1]],
          onReturn: (isMinter) => {
            assert.ok(isMinter);
          },
        },
      ]));

    it('allows minters to mint', () => {
      const newMinter = accounts[1];
      const amountToMint = 100;

      return useMethodsOn(FUSDToken, [
        {
          // Owner flags the account as a minter
          method: 'setIsMinter',
          args: [newMinter, true],
          account: accounts[0],
        },
        {
          // The newly added account mints some tokens
          method: 'mint',
          args: [newMinter, amountToMint],
          account: newMinter,
        },
        {
          // We check that the account has the minted tokens
          method: 'balanceOf',
          args: [newMinter],
          onReturn: (balance) => {
            assert.strictEqual(parseInt(balance), amountToMint);
          },
        },
      ]);
    });

    it('adds new minter on transferred ownership', () => {
      const newOwner = accounts[1];

      return useMethodsOn(FUSDToken, [
        {
          // Owner transfers ownership to the new owner
          method: 'transferOwnership',
          args: [newOwner],
          account: accounts[0],
        },
        {
          // We check that the new owner is a minter
          method: 'isMinter',
          args: [newOwner],
          onReturn: (isMinter) => {
            assert.ok(isMinter);
          },
        },
      ]);
    });

    it('throws error if user is not a minter', () => {
      const nonMinter = accounts[1];
      let errorRaised = false;

      return useMethodOn(FUSDToken, {
        method: 'mint',
        args: [nonMinter, 100],
        account: nonMinter,
        catch: (error) => {
          // We expect an error to be thrown if the user tries to mint
          // without being a minter
          errorRaised = true;
          assert.strictEqual(error, 'FlaggingMinters: caller is not a minter');
        },
      }).then(() => {
        // We check that the error was raised
        assert.ok(errorRaised);
      });
    });
  });
});
