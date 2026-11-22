  const booking = {nome:'Test',cognome:'Cliente',email:'test@example.com',normalizedEmail:'test@example.com',telefono:'3331234567',normalizedPhone:'393331234567',customerKey:'phone_393331234567',
    date:new Date('2099-01-01T00:00:00Z'),dateKey:'2099-01-01',weekday:4,time:'20:00',service:'dinner',guests:2,occasion:'',occasionCode:'none',language:'it',notes:'',
    healthDataDetected:false,healthDataConsent:false,healthDataConsentVersion:'1.0',healthDataConsentLanguage:'it',notesPurgedAt:null,healthDataConsentRecordedAt:null,
    source:'customer',bookingOrigin:'direct',privacyNoticeAccepted:true,privacyNoticeVersion:'1.0',privacyNoticeLanguage:'it',
    bookingWhatsappConsent:true,bookingWhatsappConsentVersion:'1.0',bookingWhatsappConsentSource:'customer_booking_submit',
    marketingEmailConsent:true,marketingWhatsappConsent:false,marketingConsentVersion:'2.0',marketingConsentSource:'customer_booking',
    status:'booked',autoBooked:true,autoConfirmed:true,requiresManualConfirmation:false,
    bookedBy:'automatic',confirmedAt:null,confirmedBy:null,cancelledAt:null,cancelledBy:null,
    noShowAt:null,noShowBy:null,noShowRecorded:false,requestReceivedEmailSent:false,
    confirmationEmailSent:false,cancellationEmailSent:false,rejectionEmailSent:false,
    confirmationWhatsappSent:false,cancellationWhatsappSent:false,rejectionWhatsappSent:false,adminNotificationSent:false};
  const timestamps=['privacyNoticeAcceptedAt','bookingWhatsappConsentRecordedAt','marketingConsentRecordedAt','createdAt','updatedAt','bookedAt'];

module.exports = {booking, timestamps};
