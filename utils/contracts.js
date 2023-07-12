const { formatArgs } = require('./debug');

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

const getBalanceOfUser = async (TokenContract, account) => {
  const balance = await useMethodOn(TokenContract, {
    method: 'balanceOf',
    args: [account],
    onReturn: () => {},
  });

  return parseInt(balance);
};

module.exports = {
  useMethodsOn,
  useMethodOn,
  getContractEvents,
  getBalanceOfUser,
};
