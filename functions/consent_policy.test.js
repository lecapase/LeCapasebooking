const {test} = require('node:test');
const assert = require('node:assert/strict');
const {consentState, canRecordGrant, address} = require('./consent_policy');
const legacy = {marketingEmailConsent: true, marketingEmailConsentAt: new Date(),
  marketingEmailConsentSource: 'customer_booking', marketingConsentVersion: '1.0'};
const booking = {marketingEmailConsent: true, marketingWhatsappConsent: false,
  marketingConsentRecordedAt: new Date(), marketingConsentVersion: '2.0', marketingConsentSource: 'customer_booking'};
test('only documented consent is eligible; legacy evidence is retained', () => {
  assert.equal(consentState({}, 'email'), 'unknown');
  assert.equal(consentState({marketingEmailConsent: true}, 'email'), 'unknown');
  assert.equal(consentState(legacy, 'email'), 'granted');
});
test('revocation wins over booleans, new bookings and legacy grants', () => {
  for (const profile of [{...legacy, marketingOptOutAt: new Date()},
    {...legacy, marketingEmailRevokedAt: new Date()}]) {
    assert.equal(consentState(profile, 'email'), 'revoked');
    assert.equal(canRecordGrant(profile, booking, 'email'), false);
  }
  assert.equal(canRecordGrant(legacy, booking, 'email', true), false);
  assert.equal(consentState(legacy, 'email', true), 'revoked');
});
test('channels are independent and unchecked boxes are not grants', () => {
  assert.equal(canRecordGrant({}, booking, 'email'), true);
  assert.equal(canRecordGrant({}, booking, 'whatsapp'), false);
  assert.equal(consentState({...legacy, marketingWhatsappRevokedAt: new Date()}, 'email'), 'granted');
});
test('grant requires evidence and valid form version', () => {
  for (const patch of [{marketingConsentRecordedAt: null}, {marketingConsentVersion: 'fake'},
    {marketingConsentSource: 'import'}]) {
    assert.equal(canRecordGrant({}, {...booking, ...patch}, 'email'), false);
  }
});
test('address normalization and binding prevent consent transfer', () => {
  assert.equal(address({email: ' A@EXAMPLE.COM '}, 'email'), 'a@example.com');
  assert.equal(address({telefono: '0039 3331234567'}, 'whatsapp'), '393331234567');
  assert.equal(consentState({...legacy, email: 'new@example.com', marketingEmailConsentAddress: 'old@example.com'}, 'email'), 'unknown');
});
