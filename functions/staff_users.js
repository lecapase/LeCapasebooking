const {
  onDocumentCreated,
  onDocumentUpdated,
} = require("firebase-functions/v2/firestore");

const {
  defineSecret,
} = require("firebase-functions/params");

const {
  onCall,
  HttpsError,
} = require("firebase-functions/v2/https");

const logger =
  require("firebase-functions/logger");

const {
  getAuth,
} = require("firebase-admin/auth");

const {
  getFirestore,
  FieldValue,
} = require("firebase-admin/firestore");

const nodemailer =
  require("nodemailer");

const db =
  getFirestore();

const gmailUser =
  defineSecret("GMAIL_USER");

const gmailAppPassword =
  defineSecret("GMAIL_APP_PASSWORD");

const ALLOWED_ROLES = [
  "staff",
  "supervisor",
  "manager",
  "admin",
];

const ROLE_LABELS = {
  staff:
    "Staff",

  supervisor:
    "Supervisor",

  manager:
    "Manager",

  admin:
    "Amministratore",
};

function cleanText(value) {
  return typeof value === "string" ?
    value.trim() :
    "";
}

function normalizeEmail(value) {
  return cleanText(value).toLowerCase();
}

function validRole(role) {
  return ALLOWED_ROLES.includes(role);
}

async function userIsAdmin(uid) {
  if (!uid) {
    return false;
  }

  const legacyAdminSnapshot =
    await db
        .collection("admins")
        .doc(uid)
        .get();

  if (legacyAdminSnapshot.exists) {
    return true;
  }

  const staffSnapshot =
    await db
        .collection("staff_users")
        .doc(uid)
        .get();

  if (!staffSnapshot.exists) {
    return false;
  }

  const staffData =
    staffSnapshot.data();

  return staffData &&
    staffData.active === true &&
    staffData.role === "admin";
}

function buildInviteEmail({
  displayName,
  role,
  resetLink,
}) {
  const roleLabel =
    ROLE_LABELS[role] || role;

  const text = [
    `Ciao ${displayName},`,
    "",
    "è stato creato per te un account",
    "per il gestionale Le Capase Booking.",
    "",
    `Ruolo assegnato: ${roleLabel}`,
    "",
    "Per scegliere la password e attivare",
    "l’accesso, apri questo collegamento:",
    resetLink,
    "",
    "Se non riconosci questo invito,",
    "ignora questa email.",
    "",
    "Le Capase Booking",
  ].join("\n");

  const html = `
    <div
      style="
        font-family: Arial, sans-serif;
        max-width: 620px;
        margin: 0 auto;
        padding: 24px;
        color: #1d1d1d;
      "
    >
      <div
        style="
          background: #111111;
          color: #d8b15b;
          padding: 22px;
          border-radius: 14px 14px 0 0;
          text-align: center;
        "
      >
        <h1
          style="
            margin: 0;
            font-size: 25px;
          "
        >
          Le Capase Booking
        </h1>
      </div>

      <div
        style="
          border: 1px solid #d8b15b;
          border-top: 0;
          padding: 26px;
          border-radius: 0 0 14px 14px;
        "
      >
        <p>
          Ciao <strong>${displayName}</strong>,
        </p>

        <p>
          è stato creato per te un account
          per accedere al gestionale
          <strong>Le Capase Booking</strong>.
        </p>

        <p>
          Ruolo assegnato:
          <strong>${roleLabel}</strong>
        </p>

        <p
          style="
            margin: 28px 0;
            text-align: center;
          "
        >
          <a
            href="${resetLink}"
            style="
              display: inline-block;
              background: #d8b15b;
              color: #111111;
              padding: 14px 22px;
              border-radius: 10px;
              text-decoration: none;
              font-weight: bold;
            "
          >
            SCEGLI LA PASSWORD
          </a>
        </p>

        <p>
          Dopo aver scelto la password,
          potrai entrare nel gestionale
          utilizzando il tuo indirizzo email.
        </p>

        <p
          style="
            color: #666666;
            font-size: 13px;
          "
        >
          Se non riconosci questo invito,
          puoi ignorare questa email.
        </p>
      </div>
    </div>
  `;

  return {
    text,
    html,
  };
}

async function sendInviteEmail({
  email,
  displayName,
  role,
  resetLink,
}) {
  const sender =
    gmailUser.value();

  const transporter =
    nodemailer.createTransport({
      service:
        "gmail",

      auth: {
        user:
          sender,

        pass:
          gmailAppPassword.value(),
      },
    });

  const content =
    buildInviteEmail({
      displayName,
      role,
      resetLink,
    });

  return transporter.sendMail({
    from:
      `"Le Capase Gestionale" <${sender}>`,

    replyTo:
      sender,

    to:
      email,

    subject:
      "Invito al gestionale Le Capase Booking",

    text:
      content.text,

    html:
      content.html,
  });
}

async function findOrCreateAuthUser({
  email,
  displayName,
}) {
  try {
    const existingUser =
      await getAuth()
          .getUserByEmail(email);

    await getAuth()
        .updateUser(
            existingUser.uid,
            {
              displayName,
              disabled:
                false,
            },
        );

    return getAuth()
        .getUser(existingUser.uid);
  } catch (error) {
    if (
      error &&
      error.code !==
        "auth/user-not-found"
    ) {
      throw error;
    }
  }

  return getAuth()
      .createUser({
        email,
        displayName,
        emailVerified:
          false,
        disabled:
          false,
      });
}

async function updateAuthPermissions({
  uid,
  role,
  active,
}) {
  const user =
    await getAuth()
        .getUser(uid);

  const currentClaims =
    user.customClaims || {};

  await getAuth()
      .setCustomUserClaims(
          uid,
          {
            ...currentClaims,
            role,
            staffActive:
              active,
          },
      );

  await getAuth()
      .updateUser(
          uid,
          {
            disabled:
              !active,
          },
      );
}

async function synchronizeAdminDocument({
  uid,
  email,
  displayName,
  role,
  active,
}) {
  const adminReference =
    db.collection("admins").doc(uid);

  if (
    role === "admin" &&
    active === true
  ) {
    await adminReference.set(
        {
          uid,
          email,
          displayName,
          role:
            "admin",
          active:
            true,
          updatedAt:
            FieldValue.serverTimestamp(),
        },
        {
          merge:
            true,
        },
    );

    return;
  }

  const adminSnapshot =
    await adminReference.get();

  if (adminSnapshot.exists) {
    await adminReference.delete();
  }
}

exports.onStaffUserInviteCreated =
  onDocumentCreated(
      {
        document:
          "staff_user_invites/{inviteId}",

        region:
          "europe-west1",

        secrets: [
          gmailUser,
          gmailAppPassword,
        ],
      },
      async (event) => {
        const snapshot =
          event.data;

        if (!snapshot) {
          return;
        }

        const inviteReference =
          snapshot.ref;

        const invite =
          snapshot.data();

        const displayName =
          cleanText(
              invite.displayName,
          );

        const email =
          normalizeEmail(
              invite.email,
          );

        const role =
          cleanText(
              invite.role,
          );

        const createdBy =
          cleanText(
              invite.createdBy,
          );

        try {
          await inviteReference.set(
              {
                status:
                  "processing",

                processingAt:
                  FieldValue.serverTimestamp(),
              },
              {
                merge:
                  true,
              },
          );

          if (
            displayName.length < 2
          ) {
            throw new Error(
                "Nome utente non valido.",
            );
          }

          if (
            !email.includes("@") ||
            email.length < 5
          ) {
            throw new Error(
                "Indirizzo email non valido.",
            );
          }

          if (!validRole(role)) {
            throw new Error(
                "Ruolo utente non valido.",
            );
          }

          const authorized =
            await userIsAdmin(
                createdBy,
            );

          if (!authorized) {
            throw new Error(
                "Solo un amministratore " +
                "può creare utenti.",
            );
          }

          const authUser =
            await findOrCreateAuthUser({
              email,
              displayName,
            });

          await updateAuthPermissions({
            uid:
              authUser.uid,

            role,

            active:
              true,
          });

          await db
              .collection("staff_users")
              .doc(authUser.uid)
              .set(
                  {
                    uid:
                      authUser.uid,

                    displayName,

                    email,

                    role,

                    active:
                      true,

                    createdBy,

                    createdAt:
                      FieldValue.serverTimestamp(),

                    updatedAt:
                      FieldValue.serverTimestamp(),
                  },
                  {
                    merge:
                      true,
                  },
              );

          await synchronizeAdminDocument({
            uid:
              authUser.uid,

            email,

            displayName,

            role,

            active:
              true,
          });

          const resetLink =
            await getAuth()
                .generatePasswordResetLink(
                    email,
                );

          const result =
            await sendInviteEmail({
              email,
              displayName,
              role,
              resetLink,
            });

          await inviteReference.set(
              {
                status:
                  "completed",

                uid:
                  authUser.uid,

                completedAt:
                  FieldValue.serverTimestamp(),

                emailMessageId:
                  result.messageId || null,

                error:
                  null,
              },
              {
                merge:
                  true,
              },
          );

          logger.info(
              "Utente staff creato",
              {
                uid:
                  authUser.uid,

                email,

                role,

                inviteId:
                  event.params.inviteId,
              },
          );
        } catch (error) {
          logger.error(
              "Creazione utente staff fallita",
              {
                inviteId:
                  event.params.inviteId,

                error:
                  error instanceof Error ?
                    error.message :
                    String(error),
              },
          );

          await inviteReference.set(
              {
                status:
                  "error",

                error:
                  error instanceof Error ?
                    error.message :
                    String(error),

                failedAt:
                  FieldValue.serverTimestamp(),
              },
              {
                merge:
                  true,
              },
          );
        }
      },
  );

exports.onStaffUserUpdated =
  onDocumentUpdated(
      {
        document:
          "staff_users/{staffId}",

        region:
          "europe-west1",
      },
      async (event) => {
        const beforeSnapshot =
          event.data.before;

        const afterSnapshot =
          event.data.after;

        if (
          !beforeSnapshot.exists ||
          !afterSnapshot.exists
        ) {
          return;
        }

        const before =
          beforeSnapshot.data();

        const after =
          afterSnapshot.data();

        const uid =
          event.params.staffId;

        const role =
          cleanText(
              after.role,
          );

        const active =
          after.active === true;

        if (!validRole(role)) {
          logger.error(
              "Ruolo non valido durante " +
              "l’aggiornamento utente",
              {
                uid,
                role,
              },
          );

          return;
        }

        const permissionsChanged =
          before.role !== role ||
          before.active !== active;

        const identityChanged =
          before.displayName !==
            after.displayName ||
          before.email !==
            after.email;

        if (
          !permissionsChanged &&
          !identityChanged
        ) {
          return;
        }

        const displayName =
          cleanText(
              after.displayName,
          );

        const email =
          normalizeEmail(
              after.email,
          );

        try {
          if (identityChanged) {
            await getAuth()
                .updateUser(
                    uid,
                    {
                      displayName,
                    },
                );
          }

          if (permissionsChanged) {
            await updateAuthPermissions({
              uid,
              role,
              active,
            });
          }

          await synchronizeAdminDocument({
            uid,
            email,
            displayName,
            role,
            active,
          });

          await afterSnapshot.ref.set(
              {
                updatedAt:
                  FieldValue.serverTimestamp(),

                permissionsSynchronizedAt:
                  FieldValue.serverTimestamp(),
              },
              {
                merge:
                  true,
              },
          );

          logger.info(
              "Permessi utente aggiornati",
              {
                uid,
                role,
                active,
              },
          );
        } catch (error) {
          logger.error(
              "Sincronizzazione utente fallita",
              {
                uid,

                error:
                  error instanceof Error ?
                    error.message :
                    String(error),
              },
          );
        }
      },
  );

// ============================================================
// FUNZIONI UTENTI VERSIONE 2.0
// ============================================================

async function requireAdministrator(request) {
  const uid =
    request.auth &&
    request.auth.uid;

  if (!uid) {
    throw new HttpsError(
        "unauthenticated",
        "Devi effettuare l'accesso.",
    );
  }

  if (!await userIsAdmin(uid)) {
    throw new HttpsError(
        "permission-denied",
        "Solo un amministratore puo eseguire questa operazione.",
    );
  }

  return uid;
}

async function userCanViewBookings(uid) {
  if (!uid) {
    return false;
  }

  const legacyAdminSnapshot =
    await db
        .collection("admins")
        .doc(uid)
        .get();

  if (legacyAdminSnapshot.exists) {
    return true;
  }

  const staffSnapshot =
    await db
        .collection("staff_users")
        .doc(uid)
        .get();

  if (!staffSnapshot.exists) {
    return false;
  }

  const staffData =
    staffSnapshot.data();

  return Boolean(
      staffData &&
      staffData.active === true &&
      validRole(staffData.role),
  );
}
function validatedPassword(value) {
  const password =
    typeof value === "string" ?
      value :
      "";

  if (password.length < 8) {
    throw new HttpsError(
        "invalid-argument",
        "La password deve contenere almeno 8 caratteri.",
    );
  }

  if (password.length > 128) {
    throw new HttpsError(
        "invalid-argument",
        "La password e troppo lunga.",
    );
  }

  return password;
}

exports.listActiveStaffProfiles =
  onCall(
      {
        region:
          "europe-west1",
      },
      async () => {
        const [
          staffSnapshot,
          adminSnapshot,
        ] = await Promise.all([
          db
              .collection("staff_users")
              .where("active", "==", true)
              .get(),

          db
              .collection("admins")
              .get(),
        ]);

        const profilesByUid =
          new Map();

        for (
          const document of
          staffSnapshot.docs
        ) {
          const data =
            document.data();

          const displayName =
            cleanText(
                data.displayName,
            );

          const loginEmail =
            normalizeEmail(
                data.email,
            );

          if (
            displayName.length >= 2 &&
            loginEmail.includes("@")
          ) {
            profilesByUid.set(
                document.id,
                {
                  uid:
                    document.id,

                  displayName,

                  loginEmail,
                },
            );
          }
        }

        for (
          const document of
          adminSnapshot.docs
        ) {
          if (
            profilesByUid.has(
                document.id,
            )
          ) {
            continue;
          }

          const data =
            document.data();

          if (data.active === false) {
            continue;
          }

          const displayName =
            cleanText(
                data.displayName,
            );

          const loginEmail =
            normalizeEmail(
                data.email,
            );

          if (
            displayName.length >= 2 &&
            loginEmail.includes("@")
          ) {
            profilesByUid.set(
                document.id,
                {
                  uid:
                    document.id,

                  displayName,

                  loginEmail,
                },
            );
          }
        }

        const profiles =
          [...profilesByUid.values()]
              .sort(
                  (
                      first,
                      second,
                  ) =>
                    first.displayName
                        .localeCompare(
                            second.displayName,
                            "it",
                            {
                              sensitivity:
                                "base",
                            },
                        ),
              );

        return {
          profiles,
        };
      },
  );

exports.createStaffUser =
  onCall(
      {
        region:
          "europe-west1",
      },
      async (request) => {
        const administratorUid =
          await requireAdministrator(
              request,
          );

        const data =
          request.data || {};

        const displayName =
          cleanText(
              data.displayName,
          );

        const email =
          normalizeEmail(
              data.email,
          );

        const role =
          cleanText(
              data.role,
          );

        const password =
          validatedPassword(
              data.password,
          );

        if (displayName.length < 2) {
          throw new HttpsError(
              "invalid-argument",
              "Inserisci un nome valido.",
          );
        }

        if (
          !email.includes("@") ||
          email.length < 5
        ) {
          throw new HttpsError(
              "invalid-argument",
              "Inserisci una email valida.",
          );
        }

        if (!validRole(role)) {
          throw new HttpsError(
              "invalid-argument",
              "Il ruolo selezionato non e valido.",
          );
        }

        try {
          await getAuth()
              .getUserByEmail(email);

          throw new HttpsError(
              "already-exists",
              "Esiste gia un utente con questa email.",
          );
        } catch (error) {
          if (error instanceof HttpsError) {
            throw error;
          }

          if (
            !error ||
            error.code !==
              "auth/user-not-found"
          ) {
            throw new HttpsError(
                "internal",
                "Impossibile verificare l'account.",
            );
          }
        }

        let authUser;

        try {
          authUser =
            await getAuth()
                .createUser({
                  email,
                  password,
                  displayName,
                  emailVerified:
                    false,
                  disabled:
                    false,
                });

          await updateAuthPermissions({
            uid:
              authUser.uid,

            role,

            active:
              true,
          });

          await db
              .collection("staff_users")
              .doc(authUser.uid)
              .set({
                uid:
                  authUser.uid,

                displayName,

                email,

                role,

                active:
                  true,

                passwordSetup:
                  "temporary",

                offerPasswordChange:
                  true,

                createdBy:
                  administratorUid,

                createdAt:
                  FieldValue.serverTimestamp(),

                updatedAt:
                  FieldValue.serverTimestamp(),
              });

          await synchronizeAdminDocument({
            uid:
              authUser.uid,

            email,

            displayName,

            role,

            active:
              true,
          });

          return {
            uid:
              authUser.uid,

            displayName,
          };
        } catch (error) {
          if (
            authUser &&
            authUser.uid
          ) {
            try {
              await getAuth()
                  .deleteUser(
                      authUser.uid,
                  );
            } catch (_) {
              // Ripristino non riuscito.
            }
          }

          logger.error(
              "Creazione utente 2.0 fallita",
              {
                email,

                error:
                  error instanceof Error ?
                    error.message :
                    String(error),
              },
          );

          throw new HttpsError(
              "internal",
              "Impossibile creare l'utente.",
          );
        }
      },
  );

exports.resetStaffPassword =
  onCall(
      {
        region:
          "europe-west1",
      },
      async (request) => {
        const administratorUid =
          await requireAdministrator(
              request,
          );

        const data =
          request.data || {};

        const targetUid =
          cleanText(
              data.uid,
          );

        const password =
          validatedPassword(
              data.password,
          );

        if (!targetUid) {
          throw new HttpsError(
              "invalid-argument",
              "Utente non valido.",
          );
        }

        if (
          targetUid ===
          administratorUid
        ) {
          throw new HttpsError(
              "failed-precondition",
              "Modifica la tua password dalle impostazioni personali.",
          );
        }

        const reference =
          db
              .collection("staff_users")
              .doc(targetUid);

        if (!(await reference.get()).exists) {
          throw new HttpsError(
              "not-found",
              "Utente non trovato.",
          );
        }

        await getAuth()
            .updateUser(
                targetUid,
                {
                  password,
                  disabled:
                    false,
                },
            );

        await reference.set(
            {
              active:
                true,

              passwordSetup:
                "temporary",

              offerPasswordChange:
                true,

              passwordResetBy:
                administratorUid,

              passwordResetAt:
                FieldValue.serverTimestamp(),

              updatedAt:
                FieldValue.serverTimestamp(),
            },
            {
              merge:
                true,
            },
        );

        return {
          success:
            true,
        };
      },
  );

exports.completeFirstStaffLogin =
  onCall(
      {
        region:
          "europe-west1",
      },
      async (request) => {
        const uid =
          request.auth &&
          request.auth.uid;

        if (!uid) {
          throw new HttpsError(
              "unauthenticated",
              "Devi effettuare l'accesso.",
          );
        }

        const reference =
          db
              .collection("staff_users")
              .doc(uid);

        const snapshot =
          await reference.get();

        if (!snapshot.exists) {
          throw new HttpsError(
              "not-found",
              "Profilo utente non trovato.",
          );
        }

        const requestedPassword =
          request.data &&
          request.data.password;

        const changingPassword =
          typeof requestedPassword ===
            "string" &&
          requestedPassword.length > 0;

        if (changingPassword) {
          const newPassword =
            validatedPassword(
                requestedPassword,
            );

          await getAuth()
              .updateUser(
                  uid,
                  {
                    password:
                      newPassword,
                  },
              );
        }

        await reference.set(
            {
              offerPasswordChange:
                false,

              passwordSetup:
                changingPassword ?
                  "personal" :
                  "temporary-kept",

              firstLoginCompletedAt:
                FieldValue.serverTimestamp(),

              updatedAt:
                FieldValue.serverTimestamp(),
            },
            {
              merge:
                true,
            },
        );

        return {
          success:
            true,

          passwordChanged:
            changingPassword,
        };
      },
  );

exports.notifyStaffLogin =
  onCall(
      {
        region:
          "europe-west1",

        secrets: [
          gmailUser,
          gmailAppPassword,
        ],
      },
      async (request) => {
        const uid =
          request.auth &&
          request.auth.uid;

        if (!uid) {
          throw new HttpsError(
              "unauthenticated",
              "Devi effettuare l'accesso.",
          );
        }

        const [
          staffSnapshot,
          adminSnapshot,
          authUser,
        ] = await Promise.all([
          db
              .collection("staff_users")
              .doc(uid)
              .get(),

          db
              .collection("admins")
              .doc(uid)
              .get(),

          getAuth()
              .getUser(uid),
        ]);

        let displayName =
          cleanText(authUser.displayName) ||
          "Utente gestionale";

        let role =
          "admin";

        let loginEmail =
          normalizeEmail(authUser.email);

        if (staffSnapshot.exists) {
          const staffData =
            staffSnapshot.data() || {};

          if (
            staffData.active !== true ||
            !validRole(staffData.role)
          ) {
            throw new HttpsError(
                "permission-denied",
                "Account staff non autorizzato.",
            );
          }

          displayName =
            cleanText(staffData.displayName) ||
            displayName;

          role =
            staffData.role;

          loginEmail =
            normalizeEmail(staffData.loginEmail) ||
            loginEmail;
        } else if (!adminSnapshot.exists) {
          throw new HttpsError(
              "permission-denied",
              "Account non autorizzato.",
          );
        }

        if (
          loginEmail ===
          "lecapase@outlook.com"
        ) {
          displayName =
            "Antonio Comes";
        }
        const rawRequest =
          request.rawRequest;

        const forwardedFor =
          cleanText(
              rawRequest &&
              rawRequest.headers &&
              rawRequest.headers["x-forwarded-for"],
          );

        const ipAddress =
          forwardedFor ?
            forwardedFor.split(",")[0].trim() :
            cleanText(
                rawRequest &&
                rawRequest.ip,
            ) || "Non disponibile";

        const userAgent =
          cleanText(
              rawRequest &&
              rawRequest.headers &&
              rawRequest.headers["user-agent"],
          ).slice(0, 500) ||
          "Non disponibile";

        const accessTime =
          new Intl.DateTimeFormat(
              "it-IT",
              {
                dateStyle:
                  "full",

                timeStyle:
                  "medium",

                timeZone:
                  "Europe/Rome",
              },
          ).format(new Date());

        const sender =
          gmailUser.value();

        const transporter =
          nodemailer.createTransport({
            service:
              "gmail",

            auth: {
              user:
                sender,

              pass:
                gmailAppPassword.value(),
            },
          });

        const safeDisplayName =
          displayName.replace(
              /[\r\n]+/g,
              " ",
          );

        const roleLabel =
          ROLE_LABELS[role] || role;

        const message = [
          "È stato effettuato un accesso",
          "al gestionale Le Capase Booking.",
          "",
          "Utente: " + safeDisplayName,
          "Ruolo: " + roleLabel,
          "Account: " +
            (loginEmail || "Non disponibile"),
          "Data e ora: " + accessTime,
          "Indirizzo IP: " + ipAddress,
          "Dispositivo/browser: " + userAgent,
          "",
          "Se non riconosci questo accesso,",
          "cambia immediatamente la password",
          "e disattiva l'account interessato.",
        ].join("\n");

        try {
          await transporter.sendMail({
            from:
              '"Sicurezza Le Capase" <' +
              sender +
              ">",

            to:
              sender,

            replyTo:
              sender,

            subject:
              "Accesso gestionale: " +
              safeDisplayName,

            text:
              message,
          });
        } catch (error) {
          logger.error(
              "Invio avviso accesso staff fallito.",
              {
                uid,
                role,
                error,
              },
          );

          throw new HttpsError(
              "internal",
              "Avviso di sicurezza non inviato.",
          );
        }

        logger.info(
            "Avviso accesso staff inviato.",
            {
              uid,
              role,
            },
        );

        return {
          success:
            true,
        };
      },
  );
exports.deleteStaffUser =
  onCall(
      {
        region:
          "europe-west1",
      },
      async (request) => {
        const administratorUid =
          await requireAdministrator(
              request,
          );

        const targetUid =
          cleanText(
              request.data &&
              request.data.uid,
          );

        if (!targetUid) {
          throw new HttpsError(
              "invalid-argument",
              "Utente non valido.",
          );
        }

        if (
          targetUid ===
          administratorUid
        ) {
          throw new HttpsError(
              "failed-precondition",
              "Non puoi eliminare il tuo account.",
          );
        }

        const reference =
          db
              .collection("staff_users")
              .doc(targetUid);

        if (!(await reference.get()).exists) {
          throw new HttpsError(
              "not-found",
              "Utente non trovato.",
          );
        }

        try {
          await getAuth()
              .deleteUser(
                  targetUid,
              );
        } catch (error) {
          if (
            !error ||
            error.code !==
              "auth/user-not-found"
          ) {
            throw error;
          }
        }

        await Promise.all([
          reference.delete(),

          db
              .collection("admins")
              .doc(targetUid)
              .delete(),
        ]);

        return {
          success:
            true,
        };
      },
  );

// AGENDA PROTETTA 2.0
exports.getKitchenAgenda =
  onCall(
      {
        region: "europe-west1",
        timeoutSeconds: 30,
        memory: "256MiB",
      },
      async (request) => {
        const uid =
          request.auth?.uid;

        if (!uid) {
          throw new HttpsError(
              "unauthenticated",
              "Devi effettuare l'accesso.",
          );
        }

        if (!await userCanViewBookings(uid)) {
          throw new HttpsError(
              "permission-denied",
              "Non sei autorizzato a consultare l'agenda.",
          );
        }
        const dateKey =
          typeof request.data?.dateKey === "string" ?
            request.data.dateKey.trim() :
            "";

        if (
          !/^\d{4}-\d{2}-\d{2}$/.test(dateKey)
        ) {
          throw new HttpsError(
              "invalid-argument",
              "Data agenda non valida.",
          );
        }

        const requestedDate =
          new Date(dateKey + "T00:00:00Z");

        if (
          Number.isNaN(requestedDate.getTime()) ||
          requestedDate
              .toISOString()
              .slice(0, 10) !== dateKey
        ) {
          throw new HttpsError(
              "invalid-argument",
              "Data agenda non valida.",
          );
        }

        const today =
          new Date();

        const todayUtc =
          new Date(
              Date.UTC(
                  today.getUTCFullYear(),
                  today.getUTCMonth(),
                  today.getUTCDate(),
              ),
          );

        const maximumDate =
          new Date(todayUtc);

        maximumDate.setUTCDate(
            maximumDate.getUTCDate() + 366,
        );

        if (
          requestedDate < todayUtc ||
          requestedDate > maximumDate
        ) {
          throw new HttpsError(
              "invalid-argument",
              "La data deve essere compresa nei prossimi 366 giorni.",
          );
        }

        const snapshot =
          await db
              .collection("bookings")
              .where(
                  "dateKey",
                  "==",
                  dateKey,
              )
              .get();

        const hiddenStatuses =
          new Set([
            "cancelled",
            "rejected",
            "no_show",
          ]);

        const bookings =
          snapshot.docs
              .map((document) => document.data())
              .filter((booking) => {
                const status =
                  String(
                      booking.status ||
                      "pending",
                  );

                return !hiddenStatuses.has(status);
              })
              .map((booking) => ({
                nome:
                  String(booking.nome || ""),

                cognome:
                  String(booking.cognome || ""),

                guests:
                  Number.isFinite(
                      Number(
                          booking.guests ??
                          booking.persone,
                      ),
                  ) ?
                    Number(
                        booking.guests ??
                        booking.persone,
                    ) :
                    0,

                time:
                  String(
                      booking.time ||
                      booking.orario ||
                      "",
                  ),

                service:
                  booking.service === "lunch" ?
                    "lunch" :
                    "dinner",

                status:
                  String(
                      booking.status ||
                      "pending",
                  ),

                occasion:
                  String(
                      booking.occasion ||
                      booking.occasione ||
                      "",
                  ),

                notes:
                  String(
                      booking.notes ||
                      booking.note ||
                      "",
                  ),
              }))
              .sort((first, second) =>
                first.time.localeCompare(
                    second.time,
                ),
              );

        return {
          dateKey,
          bookings,
        };
      },
  );
