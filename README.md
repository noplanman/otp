# One-time Password Generator

A simple command line tool to generate TOTP([RFC 6238](https://tools.ietf.org/html/rfc6238), aka [Google Authenticator](https://en.wikipedia.org/wiki/Google_Authenticator)) based on [mdp/rotp](https://github.com/mdp/rotp).

## Prepare

First, we should install dependencies, as always.

```bash
bundle install --without development
```

Then, create a `.otp.yml` in your home folder (i.e. `vim ~/.otp.yml`) like below:

```yaml
otp:
  google:
    secret: YOUR_GOOGLE_AUTHENTICATOR_TOKEN_HERE
    issuer: Google
    username: YOUR_GOOGLE_USERNAME_OR_EMAIL
  github:
    secret: YOUR_GITHUB_AUTHENTICATOR_TOKEN_HERE
    issuer: GitHub
    username: YOUR_GITHUB_USERNAME_OR_EMAIL
```

Each item consists of **at least** the `secret` and can also have optional `issuer` and `username` values.

**IMPORTANT!! Remember to set the file permissions to prevent other users from getting your secret tokens!**

```bash
chmod 600 ~/.otp.yml
```

If you wish, create a symlink of `main.rb`.

```bash
ln -s <THIS_REPO_DIR>/main.rb /usr/local/bin/otp
```

## Usage

```
Usage: otp [options] [SITE_NAME]
    -c, --config FILE                Specify a .otp.yml file (Default: ~/.otp.yml)
    -C, --copy                       Copy code to clipboard
    -b, --base32                     Create a random Base32 string
    -l, --list                       Output a list of all available sites
    -q, --qrcode                     Create and output QR code
    -Q, --qrcode-out FILE            Save QR code to file
    -I, --qrcode-in FILE             Get OTP info from QR code image file (must be .png)
    -h, --help                       Display this screen
```

## To-Do List

- [x] Add support for X11 clipboard using `xclip`.
- [ ] Add HOTP([RFC 4226](https://tools.ietf.org/html/rfc4226)) support.
- [ ] Package it to [homebrew](http://brew.sh).

Issues and pull requests are always welcome.
