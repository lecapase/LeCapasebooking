const roles = new Set(['admin', 'manager', 'supervisor', 'staff']);

function effectiveProfile(staff, legacy) {
  return staff.exists ? staff.data() : legacy?.data();
}

function canViewBookings(profile) {
  return profile?.active === true && roles.has(profile.role);
}

async function getProfile(db, uid) {
  if (!uid) return null;
  const staff = await db.collection('staff_users').doc(uid).get();
  if (staff.exists) return staff.data();
  const legacy = await db.collection('admins').doc(uid).get();
  const data = legacy.data();
  return data?.role === 'admin' ? data : null;
}

async function notificationTokens(db) {
  const [devices, legacy] = await Promise.all([
    db.collection('notification_devices').get(), db.collection('admins').get(),
  ]);
  const legacyById = new Map(legacy.docs.map(doc => [doc.id, doc]));
  const deviceById = new Map(devices.docs.map(doc => [doc.id, doc]));
  const ids = [...new Set([...legacyById.keys(), ...deviceById.keys()])];
  const tokens = new Set();
  for (let start = 0; start < ids.length; start += 200) {
    const profiles = await db.getAll(...ids.slice(start, start + 200)
      .map(uid => db.collection('staff_users').doc(uid)));
    for (const staff of profiles) {
      const legacyDoc = legacyById.get(staff.id);
      const profile = effectiveProfile(staff, legacyDoc);
      if (!canViewBookings(profile) || (!staff.exists && profile.role !== 'admin')) continue;
      for (const doc of [deviceById.get(staff.id), legacyDoc]) {
        const values = doc?.data()?.fcmTokens;
        if (!Array.isArray(values)) continue;
        for (const token of values) {
          if (typeof token === 'string' && token.trim()) tokens.add(token.trim());
        }
      }
    }
  }
  return [...tokens];
}

module.exports = {getProfile, canViewBookings, notificationTokens};
