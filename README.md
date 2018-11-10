# One-time Password Generator

---

🚀 Development has moved to **[git.feneas.org]**.

(The repository on GitHub is only a mirror, so fork on Feneas to contribute. No registration needed, just sign in with your GitHub account.)

---

A simple command line tool to generate TOTP([RFC 6238], aka [Google Authenticator]) based on [mdp/rotp].

## Prepare

Clone or download this repository to your computer (`<OTP_DIR>` will be the directory you clone/download to).

```bash
# Create <OTP_DIR> and change into it:
$ mkdir -p <OTP_DIR> && cd <OTP_DIR>

# If you want to clone the repo:
$ git clone https://git.feneas.org/noplanman/otp .

# If you want to download the repo:
$ curl -sL https://git.feneas.org/noplanman/otp/-/archive/master/otp-master.tar.gz | tar xf - --strip-components 1
```

First, we need to install dependencies, as always:

```bash
$ bundle install --without development
```

Then, for simplicity of use, create a symlink of `main.rb`:

```bash
$ ln -s main.rb /usr/local/bin/otp
```

Now, either use `otp -a` to create the config file and add a site:

```bash
$ otp -a
'/Users/noplanman/.otp.yml' not found. Create it? y
Site name *: mastodon
Secret *: YOUR_MASTODON_AUTHENTICATION_TOKEN_HERE
Issuer *: |mastodon| Mastodon
Username: YOUR_MASTODON_USERNAME_OR_EMAIL
Recovery keys (end with blank line):
recovery1
recovery2

Added 'mastodon'
```

*or* manually create `.otp.yml` in your home folder (i.e. `vim ~/.otp.yml`) like below:

```yaml
otp:
  gitlab:
    secret: YOUR_GITLAB_AUTHENTICATION_TOKEN_HERE
    issuer: GitLab
    username: YOUR_GITLAB_USERNAME_OR_EMAIL
    recovery_keys:
    - recovery1
    - recovery2
  mastodon:
    secret: YOUR_MASTODON_AUTHENTICATION_TOKEN_HERE
    issuer: Mastodon
    username: YOUR_MASTODON_USERNAME_OR_EMAIL
    recovery_keys:
    - recovery1
    - recovery2
  my_app:
    secret: SOME_OTHER_AUTHENTICATION_TOKEN_HERE
    issuer: My App
    recovery_keys: single_recovery_key
```

Each site is case sensitive and consists of **at least**:
- `secret`: The Base32 secret provided by the service you're setting up the OTP for.
- `issuer`: Name of the service (e.g. `Mastodon`).

and can optionally have:
- `username`: Your username for the service (e.g. `jahnny`).
- `recovery_keys`: OTP recovery keys provided by the service (can be a single string or array of strings).

**IMPORTANT!! When manually creating the config file, remember to set the file permissions to prevent other users from getting your secret tokens!**

```bash
$ chmod 600 ~/.otp.yml
```

## Usage

```
Usage: otp [options] [SITE_NAME]
    -c, --config FILE                Specify a .otp.yml file (Default: ~/.otp.yml)
    -C, --copy                       Copy code to clipboard
    -b, --base32                     Create a random Base32 string
    -l, --list                       Output a list of all available sites
    -a, --add                        Add a new site
    -d, --delete                     Delete an existing site
    -r, --recovery                   Get one of the recovery keys (random)
    -q, --qrcode                     Create and output QR code
    -Q, --qrcode-out FILE            Save QR code to file
    -I, --qrcode-in FILE             Get OTP info from QR code image file (must be .png)
    -h, --help                       Display this screen
```

## To-Do List

- [ ] Add HOTP ([RFC 4226]) support.
- [ ] Package it to [Homebrew].
- [ ] Encryption with password protection for sites config file.
- [ ] Import / Export in various formats.

## Contributing

[Issues] and [Merge Requests] are always welcome!


[git.feneas.org]: https://git.feneas.org/noplanman/otp
[RFC 4226]: https://tools.ietf.org/html/rfc4226
[RFC 6238]: https://tools.ietf.org/html/rfc6238
[Google Authenticator]: https://en.wikipedia.org/wiki/Google_Authenticator
[mdp/rotp]: https://github.com/mdp/rotp
[Homebrew]: https://brew.sh
[Issues]: https://git.feneas.org/noplanman/otp/issues
[Merge Requests]: https://git.feneas.org/noplanman/otp/merge_requests  
