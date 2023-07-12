const cron = require('node-cron');

const everyMinute = '* * * * *';
const everyFiveSeconds = '*/5 * * * * *';
const everySecond = '* * * * * *';

const schedule = (cronTime, callback) => cron.schedule(cronTime, callback);

module.exports = {
  everyMinute,
  everyFiveSeconds,
  everySecond,
  schedule,
};
