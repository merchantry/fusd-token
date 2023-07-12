# fusd-token

```
git clone https://github.com/merchantry/fusd-token.git
cd fusd-token
npm install
npm run test
```

# flatten

Run `npm run flatten` command to add all the smart contracts in the first level of `contracts/` folder as flattened versions in the `flattened/` folder

# tests

Use helper `useMethodsOn` to asynchronously and consecutively call methods on a compiled contract

# cron-jobs

run `npm run cron-job -- PROVIDER PRIVATE_KEY SALE_CONTRACT_ADDRESS` to initiate a cron job which will check for debtors below LT every minute and liquidate them if there are any
