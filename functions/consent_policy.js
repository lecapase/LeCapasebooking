const crypto = require('node:crypto');
const channels = {email: 'Email', whatsapp: 'Whatsapp'};
function prefix(channel) {
  if (!channels[channel]) throw new Error('Invalid consent channel');
  return `marketing${channels[channel]}`;
}
function hash(value) { return crypto.createHash('sha256').update(value).digest('hex'); }
function address(profile, channel) {
  if (channel === 'email') return String(profile.normalizedEmail || profile.email || '').trim().toLowerCase();
  let phone = String(profile.normalizedPhone || profile.telefono || '').replace(/\D/g, '');
  if (phone.startsWith('00')) phone = phone.slice(2);
  if (phone.length === 10 && phone.startsWith('3')) phone = `39${phone}`;
  return phone;
}
function consentState(profile, channel, suppressed = false) {
  const p = prefix(channel);
  if (suppressed || profile[`${p}RevokedAt`] || profile.marketingOptOutAt) return 'revoked';
  if (profile[`${p}ConsentAddress`] && profile[`${p}ConsentAddress`] !== address(profile, channel)) return 'unknown';
  if (profile[`${p}Consent`] === true && profile[`${p}ConsentAt`] &&
      (profile[`${p}ConsentSource`] || profile.marketingConsentSource) &&
      (profile[`${p}ConsentVersion`] || profile.marketingConsentVersion)) return 'granted';
  return 'unknown';
}
function canRecordGrant(profile, booking, channel, suppressed = false) {
  const p = prefix(channel);
  return consentState(profile, channel, suppressed) !== 'revoked' &&
    booking[`${p}Consent`] === true &&
    !!booking.marketingConsentRecordedAt &&
    booking.marketingConsentSource === 'customer_booking' &&
    ['1.0', '2.0'].includes(booking.marketingConsentVersion);
}
module.exports = {prefix, hash, address, consentState, canRecordGrant};
