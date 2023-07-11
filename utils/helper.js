const { formatArgs } = require('./debug');

const randomInt = (min, max) => {
  const diff = max - min;
  return Math.round(Math.random() * diff) + min;
};

const randomElement = (array) => array[randomInt(0, array.length - 1)];

const newArray = (length, callback) => {
  const array = [];
  for (let i = 0; i < length; i++) array.push(callback(i));
  return array;
};

const idsFrom = (fromId, length) => newArray(length, (i) => fromId + i);

const timeInSecs = () => Math.round(Date.now() / 1000);

const secondsInTheFuture = (seconds) => timeInSecs() + seconds;

const runPromisesInSequence = (promiseArray) =>
  promiseArray.reduce(
    (p, promise, index) => p.then((prev) => promise(prev, index)),
    Promise.resolve()
  );

const useMethodsOn = (contractInstance, methods) => {
  if (methods.length === 0) return Promise.resolve();

  const recursiveFunction = (methodIndex, promise) =>
    promise.then(async (previousReturnValue) => {
      if (!methods[methodIndex]) return previousReturnValue;

      const {
        method,
        args = [],
        account,
        onReturn,
        wait = null,
        then = null,
        catch: catchCallback,
      } = methods[methodIndex];

      if (wait) {
        const waitPromise = new Promise((resolve) => {
          setTimeout(() => resolve(), wait);
        });
        return recursiveFunction(methodIndex + 1, waitPromise);
      }

      if (then) {
        then(await previousReturnValue);
        return recursiveFunction(methodIndex + 1, Promise.resolve());
      }

      if (!contractInstance.methods[method])
        throw new Error(`Unknown method called ${method}`);

      const requestInstance = contractInstance.methods[method](...args)
        [onReturn ? 'call' : 'send']({
          from: account,
          gas: '1000000000',
        })
        .catch(() =>
          contractInstance.methods[method](...args)
            .call({ from: account })
            .catch((err) => {
              const reason = err.message.split(': revert ')[1];

              if (!catchCallback) {
                throw new Error(
                  `Calling method ${
                    contractInstance.options.name
                  } ${method}${formatArgs(args)} ${reason}`
                );
              }
              catchCallback(reason);
            })
        );

      if (onReturn) onReturn(await requestInstance, await previousReturnValue);
      return recursiveFunction(methodIndex + 1, requestInstance);
    });

  return recursiveFunction(0, Promise.resolve());
};

const useMethodOn = (contractInstance, params) =>
  useMethodsOn(contractInstance, [params]);

const getContractEvents = async (contractInstance, eventName = 'allEvents') =>
  contractInstance.getPastEvents(eventName).then((events) =>
    events.map(({ event, returnValues }) => ({
      event,
      data: Object.entries(returnValues).reduce((data, [key, value]) => {
        if (/^\d*$/.test(key)) return data;
        data[key] = value;
        return data;
      }, {}),
    }))
  );

const zeroOrOne = () => randomInt(0, 1);

const getBalanceOfUser = async (TokenContract, account) => {
  const balance = await useMethodOn(TokenContract, {
    method: 'balanceOf',
    args: [account],
    onReturn: () => {},
  });

  return parseInt(balance);
};

const valuesWithin = (a, b, delta) => Math.abs(a - b) <= delta;

const getTaxFunction = (taxPercentage) => (amount) =>
  Math.round((amount / (100 - taxPercentage)) * 100);

const valuesWithinPercentage = (value1, value2, percentage) => {
  const diff = Math.abs(value1 - value2);
  const maxDiff = Math.max(value1, value2) * (percentage / 100);

  return diff <= maxDiff;
};

const mapObject = (object, callback) =>
  Object.fromEntries(
    Object.entries(object).map(([key, value]) => [key, callback(value)])
  );

module.exports = {
  secondsInTheFuture,
  randomInt,
  randomElement,
  idsFrom,
  timeInSecs,
  runPromisesInSequence,
  useMethodsOn,
  useMethodOn,
  getContractEvents,
  zeroOrOne,
  newArray,
  getBalanceOfUser,
  valuesWithin,
  getTaxFunction,
  valuesWithinPercentage,
  mapObject,
};
