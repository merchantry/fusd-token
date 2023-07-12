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

const zeroOrOne = () => randomInt(0, 1);

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
  zeroOrOne,
  newArray,
  valuesWithin,
  getTaxFunction,
  valuesWithinPercentage,
  mapObject,
};
