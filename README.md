[![Discord](https://img.shields.io/discord/1468295714961494029?color=7289da&label=Join%20Our%20Discord&logo=discord&logoColor=white&style=for-the-badge)]([![Discord](https://img.shields.io/discord/1468295714961494029?color=7289da&label=Join%20Our%20Discord&logo=discord&logoColor=white&style=for-the-badge)](https://discord.gg/UbPRh74PzV))


# 🔧 Waydroid WhatsApp Google Account Visibility Fix

A small Linux script that fixes an issue where **WhatsApp running inside Waydroid cannot see an existing Google account** when attempting to restore a Google Drive backup.

Instead of showing your Google account, WhatsApp's account picker may only display:

> **Choose an account**  
> Add account

even though the Google account is already successfully added to Waydroid.

This script automatically adds WhatsApp to Android's account visibility database and makes the existing Google account visible to WhatsApp.

---

## ✨ Features

- 🔍 Automatically detects Google accounts inside Waydroid
- 📱 Checks whether WhatsApp is installed
- 🔐 Adds explicit Google account visibility for `com.whatsapp`
- 💾 Creates a timestamped backup before modifying anything
- ✅ Verifies that the modification was successful
- 👥 Supports multiple Google accounts
- 🔄 Restarts the Waydroid container after applying the fix
- 🖥️ Runs directly from your normal Linux terminal
- ❌ No hard-coded Google account address or Android account ID

---

## 🐛 The Problem

On some Waydroid installations with Google Play Services/GApps, WhatsApp can reach the Google Drive backup restore screen but fail to see Google accounts already configured in Android.

You may see:

```text
Choose an account

+ Add account

              Cancel
```

Your Google account may still exist normally under Android's account settings and be visible to Google Play Services and the Play Store.

The issue can be caused by Android's **per-application account visibility**.

For example, the Android account visibility database may contain:

```text
com.android.vending    2
com.google.android.gms 2
```

while there is no entry for:

```text
com.whatsapp
```

---

## 🛠️ What This Script Does

Android stores account visibility information in:

```text
/data/system_de/0/accounts_de.db
```

The script detects the Google account and its internal account ID.

It then creates an explicit visibility entry for WhatsApp:

```text
com.whatsapp = 1
```

Internally, the important database operation is equivalent to:

```sql
INSERT OR REPLACE INTO visibility
(
    accounts_id,
    _package,
    value
)
VALUES
(
    <GOOGLE_ACCOUNT_ID>,
    'com.whatsapp',
    1
);
```

Visibility value `1` corresponds to an explicitly visible account.

The script **does not hard-code the account ID**. It automatically obtains the correct ID from Android's account database.

---

## ⚠️ Important

This script directly modifies an **internal Android system SQLite database** inside Waydroid.

Although a backup is created automatically before modification, directly editing Android system databases is inherently more invasive than using a supported Android API.

Use it at your own risk.

The script was created specifically as a workaround for Waydroid installations where the Google account exists but WhatsApp's account picker does not expose it.

---

## 📋 Requirements

You need:

- Linux
- Waydroid
- A Waydroid image with Google services/GApps
- A Google account already added to Waydroid
- WhatsApp installed inside Waydroid
- `sqlite3` available inside the Waydroid Android image
- `sudo` access on the Linux host

The script currently expects the Android account database at:

```text
/data/system_de/0/accounts_de.db
```

This location is used by the Waydroid/Android configuration the script was developed and tested against.

---

## 📦 Installation

Clone this repository:

```bash
git clone https://github.com/Nigel1992/WhatsApp-on-Waydroid.git
cd WhatsApp-on-Waydroid
```

Make the script executable:

```bash
chmod +x fix-waydroid-whatsapp-google-account.sh
```

---

## 🚀 Usage

Run the script from your **normal Linux terminal**:

```bash
./fix-waydroid-whatsapp-google-account.sh
```

You do **not** need to enter:

```bash
sudo waydroid shell
```

first.

The script will request administrator privileges automatically when required.

---

## 🔎 What Happens When You Run It?

The script will:

1. Request `sudo` privileges.
2. Check that Waydroid is installed.
3. Make sure the Waydroid container is running.
4. Locate/check the Android account database.
5. Check that `sqlite3` is available.
6. Detect Google accounts automatically.
7. Check that WhatsApp is installed.
8. Check the existing account visibility state.
9. Create a timestamped backup of the database.
10. Add `com.whatsapp` with visibility value `1`.
11. Verify that the new database entry exists.
12. Restart the Waydroid container.

If multiple Google accounts exist, the script allows you to select which one should be exposed to WhatsApp.

---

## 💾 Automatic Backup

Before changing the database, the script creates a backup similar to:

```text
/data/system_de/0/accounts_de.db.backup-whatsapp-2026-09-07_20-55-12
```

The original database therefore has a recovery copy available if something goes wrong.

---

## ✅ After Running the Fix

When the script finishes, start the Waydroid session if necessary:

```bash
waydroid session start
```

Open WhatsApp and continue to:

```text
Restore backup
      ↓
Choose an account
```

Your existing Google account should now appear in the account chooser.

---

## 🔬 Manual Verification

You can inspect Android's account visibility information with:

```bash
sudo waydroid shell -- dumpsys account
```

Or inspect the relevant database entries directly:

```bash
sudo waydroid shell -- sqlite3 /data/system_de/0/accounts_de.db \
"SELECT * FROM visibility;"
```

After a successful fix, an entry similar to this should exist:

```text
8|com.whatsapp|1
```

The first number is Android's internal account ID and **will differ between installations**.

---

## 🧠 Why Not Hard-Code the Account ID?

Android assigns an internal ID to each account.

For example, one installation might have:

```text
8|example@gmail.com|com.google
```

while another installation might use:

```text
3|example@gmail.com|com.google
```

The ID can also change after removing/re-adding accounts or reinstalling Android/Waydroid.

For this reason, the script queries:

```sql
SELECT _id, name
FROM accounts
WHERE type='com.google';
```

and uses the detected ID automatically.

---

## 🆘 Troubleshooting

### No Google account found

Make sure your Google account has already been added inside Waydroid.

Open Android settings and add it through:

```text
Settings
→ Accounts
→ Add account
→ Google
```

Then run the script again.

### WhatsApp is not found

Make sure the standard WhatsApp package is installed:

```text
com.whatsapp
```

You can check with:

```bash
sudo waydroid shell -- pm path com.whatsapp
```

### Account still doesn't appear

Check the visibility database:

```bash
sudo waydroid shell -- sqlite3 /data/system_de/0/accounts_de.db \
"SELECT * FROM visibility;"
```

You should see an entry ending in:

```text
|com.whatsapp|1
```

Then completely restart Waydroid:

```bash
waydroid session stop
sudo systemctl restart waydroid-container
waydroid session start
```

Try the WhatsApp account chooser again.

---

## 🔄 Restoring the Backup

If you need to undo a database modification, **stop Waydroid before restoring the database**.

First list available backups:

```bash
sudo waydroid shell -- ls -lh /data/system_de/0/accounts_de.db.backup-whatsapp-*
```

Because Android's account database may use SQLite WAL files while running, restoration should only be attempted while the Android/Waydroid environment is stopped.

Do not blindly replace a live account database.

---

## 🔒 Privacy

The script does not:

- Upload your Google account information
- Send data to an external server
- Store your Google password
- Access your Google Drive files
- Modify WhatsApp messages or backups
- Require your Google password

The Google account address may be displayed locally in the terminal when the script detects available accounts.

All operations happen locally on your Waydroid installation.

---

## 🧪 Tested With

Initially developed and confirmed working with:

- Waydroid
- Android 11
- Google Play Services / GApps
- WhatsApp package `com.whatsapp`
- Linux host

Other Android/Waydroid versions may use different database structures or paths.

Reports from other configurations are welcome.

---

## 🤝 Contributing

Bug reports, improvements and compatibility reports are welcome.

When reporting a problem, please include:

```bash
waydroid --version
```

and:

```bash
sudo waydroid shell -- getprop ro.build.version.release
```

Please **remove personal information such as Google account addresses from logs before posting them publicly**.

Pull requests are welcome.

---

## ⚖️ Disclaimer

This is an unofficial community workaround.

This project is not affiliated with, endorsed by, or associated with WhatsApp, Meta, Google, Android, or Waydroid.

Use this script at your own risk. Always keep backups of important data.

---

## ⭐ Support

If this fixed the missing Google account problem for you, consider starring the repository.

Compatibility reports are especially useful so the script can be improved for additional Waydroid and Android versions.