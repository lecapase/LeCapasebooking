const {test} = require('node:test');
const assert = require('node:assert/strict');
const {previousBusinessDate, validReviewUrl, visitEligible, contact, message} = require('./review_requests');
const url = 'https://g.page/r/CVT1Lz6T5_JyEBM/review';
test('previous date uses Rome timezone across midnight, DST and year boundaries', () => {
  assert.equal(previousBusinessDate(new Date('2026-09-26T22:30:00Z')), '2026-09-26');
  assert.equal(previousBusinessDate(new Date('2026-01-01T10:00:00Z')), '2025-12-31');
  assert.equal(previousBusinessDate(new Date('2026-03-29T09:00:00Z')), '2026-03-28');
  assert.equal(previousBusinessDate(new Date('2026-10-25T10:00:00Z')), '2026-10-24');
});
test('only released and completed visits from yesterday are eligible', () => {
  for (const status of ['released', 'completed']) assert.equal(visitEligible({status,dateKey:'2026-09-26'}, '2026-09-26'),true);
  for (const status of ['arrived','cancelled','no_show','pending','booked','confirmed','rejected']) {
    assert.equal(visitEligible({status,dateKey:'2026-09-26'}, '2026-09-26'),false);
  }
  assert.equal(visitEligible({status:'released',dateKey:'2026-09-25'},'2026-09-26'),false);
});
test('accepts supplied direct Google link and rejects other destinations', () => {
  assert.equal(validReviewUrl(url),true);
  for (const bad of ['', 'http://g.page/r/test/review','https://g.page.evil.test/r/test/review',
    'https://user@g.page/r/test/review','javascript:alert(1)','https://g.page/place']) {
    assert.equal(validReviewUrl(bad),false);
  }
});
test('deduplication keys normalize phone and email; messages use Le Capase', () => {
  const a = contact({email:' A@Example.COM ',telefono:'3331234567'});
  const b = contact({email:'a@example.com',telefono:'+39 3331234567'});
  assert.deepEqual(a,b);
  assert.equal(contact({email:'invalid'}),null);
  const msg = message(url,'https://example.com/unsubscribe?a=1&b=2');
  assert.match(msg.text,/Grazie per aver scelto Le Capase!/);
  assert.doesNotMatch(msg.text,/alle Capase/);
  assert.match(msg.html,/a=1&amp;b=2/);
  assert.match(message(url,'https://example.com','en').text,/Thank you for visiting Le Capase/);
});
