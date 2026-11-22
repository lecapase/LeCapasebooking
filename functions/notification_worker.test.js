const {test} = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
const path = require('node:path');

function worker() {
  const shown = [];
  const opened = [];
  const handlers = {};
  vm.runInNewContext(fs.readFileSync(path.join(__dirname, '../web/firebase-messaging-sw.js'), 'utf8'), {
    importScripts() {},
    firebase: {initializeApp() {}, messaging: () => ({onBackgroundMessage: fn => handlers.message = fn})},
    self: {registration: {showNotification: (...args) => shown.push(args)}, addEventListener: (type, fn) => handlers[type] = fn},
    clients: {matchAll: async () => [], openWindow: async url => opened.push(url)},
  });
  return {shown, opened, handlers};
}

test('FCM notification payload is not displayed twice', async () => {
  const w = worker();
  await w.handlers.message({notification: {title: 'Booking'}, data: {bookingId: 'test'}});
  assert.equal(w.shown.length, 0);
});
test('data-only push displays once and opens notifications', async () => {
  const w = worker();
  await w.handlers.message({data: {bookingId: 'test'}});
  assert.equal(w.shown.length, 1);
  assert.equal(w.shown[0][1].tag, 'test');
  let pending;
  w.handlers.notificationclick({notification: {data: w.shown[0][1].data, close() {}}, waitUntil: p => pending = p});
  await pending;
  assert.deepEqual(w.opened, ['/?view=notifications']);
});
