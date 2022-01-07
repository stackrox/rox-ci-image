#!/usr/bin/env bats

# To run the test locally do:
# docker build -t apollo-cci:test -f images/test.cci-export.Dockerfile images && docker run -it apollo-cci:test

bats_helpers_root="/usr/lib/node_modules"
load "${bats_helpers_root}/bats-support/load.bash"
load "${bats_helpers_root}/bats-assert/load.bash"

setup() {
  export _FILE="$HOME/test/bats/FILE"
  # Create a file used in test-cases using subshell execution of 'cat'
  echo "1.2.3" > "${_FILE}"
  run test -f "${_FILE}"
  assert_success

  bash_env="$(mktemp)"
  export BASH_ENV="$bash_env"
  # ensure clean start of every test case
  unset FOO
  echo "" > "$bash_env"
  run echo $BASH_ENV
  assert_output "$bash_env"
  run cat $BASH_ENV
  assert_output ""
  run "$HOME/test/foo-printer.sh"
  assert_output "FOO: "
  run test -n $CIRCLECI
  assert_success
  run echo $CIRCLECI
  assert_output "true"
}

@test "cci-export BASH_ENV does not exist" {
  run rm -f "${BASH_ENV}"
  run test -f "${BASH_ENV}"
  assert_failure

  run cci-export FOO cci1
  assert_success
  run "$HOME/test/foo-printer.sh"
  assert_output "FOO: cci1"
  refute_output "FOO: "
}

@test "cci-export sanity check single value" {
  run cci-export FOO cci1
  assert_success
  run "$HOME/test/foo-printer.sh"
  assert_output "FOO: cci1"
  refute_output "FOO: "

  run cci-export FOO cci2
  assert_success
  run "$HOME/test/foo-printer.sh"
  assert_output "FOO: cci2"
  refute_output "FOO: cci1"
}

@test "cci-export should escape special characters in values" {
  run cci-export FOO 'quay.io/rhacs-"eng"/super $canner:2.21.0-15-{{g44}(8f)2dc8fa}'
  assert_success
  run "$HOME/test/foo-printer.sh"
  assert_output 'FOO: quay.io/rhacs-"eng"/super $canner:2.21.0-15-{{g44}(8f)2dc8fa}'
  refute_output "FOO: "
}

@test "cci-export should escape special characters multiline strings" {
  # Sanity check on cert test fixture
  export _CERT="$HOME/test/bats/test-ca.crt"
  run test -f "${_CERT}"
  assert_success
  # The cert should be parsable with openssl
  run openssl x509 -in "${_CERT}" -noout
  assert_success

  run cci-export CERT "$(cat ${_CERT})"
  assert_success

  post_cert="$(mktemp)"
  "$HOME/test/foo-printer.sh" CERT --silent > "$post_cert"
  # openssl should be able to load the cert after processing it with cci-export
  run openssl x509 -in "$post_cert" -noout
  assert_success

  # assert_output --partial 'FOO: -----BEGIN CERTIFICATE-----\nM'
  # refute_output --partial 'FOO: -----BEGIN CERTIFICATE-----nM'

  # // cert_test.go:43: testCentralCertCAPEM=$'-----BEGIN CERTIFICATE-----nMIIC0zCCAbugAwIBAgIUSFuSMLD/aC2joxO+PejsFLyXQuMwDQYJKoZIhvcNAQELnBQAwGTEXMBUGA1UEAwwOUm9vdCBTZXJ2ZXIgQ0EwHhcNMjIwMTA2MTY0MzA5WhcNnMjIwMjA1MTY0MzA5WjAZMRcwFQYDVQQDDA5Sb290IFNlcnZlciBDQTCCASIwDQYJnKoZIhvcNAQEBBQADggEPADCCAQoCggEBAKKcTJ+DYLpFWVPcKFzu+O205SNULgJ7ngAnBpwezFWVUgolf1rsvBX5nS8kXi7kVN5xGBE5cVuI3yqTtIdjpMi5Nt0vznAFln3pEf/P4rt6BqmzQiUBXaoWtEo0tMqC1eMxhQjLM80DQDxjzBcKsVwKLYGxGf0cPSnXpn8A9yWuyoU8zMRcu18awUHOCr1Ugv+q/SjlLASrZs0l5sRQaaAqILVkcUeY1tNntyINELmvYtolDrlNVgijrMsRRCLHbOZgcBZMZsf8O9skLuKAVX89OvIz1NJoOcminKHVvYP3YL5hsjWHvHIqixQC5AlRIG14AmYZjnNhZWJho8yPuQ5B/vrsCAwEAAaMTnMBEwDwYDVR0TBAgwBgEB/wIBATANBgkqhkiG9w0BAQsFAAOCAQEAVcakPXtKjDSNnlkre2xaYuYktTdeqgCkaR/533o17p+6k51Uz/yV4VhddaE6BYxiEsERVeC0lbO4anoU5gsKapqpypxhzxqV/npMcN8l8zw8lh9jD7NCD3UN+0+Y2xufrvZEE3LH31hdL2nNJ2xrzZohrY0a0PS9brlxNVgewUcsI6ldhxQN0tC4v4BYYrESrmDMXqL/cGbs+o9n6GkNpjL38PXbitIBha7YV3VulfVutWLZEmVfmeoJjP3vpMh6x9wfuRefbZ2U4GM2nhfJNWlEHt15qxlkF0gVTUn8jlr6f6Ww/o3UDSzfu6yLExj6ldnA4NGf58mqF5vFPnDNY/2odaPw==n-----END CERTIFICATE-----'
  # export ROX_TEST_CA_PEM="${ROX_TEST_CA_PEM:-"$'-----BEGIN CERTIFICATE-----\nMIIC0zCCAbugAwIBAgIUSFuSMLD/aC2joxO+PejsFLyXQuMwDQYJKoZIhvcNAQEL\nBQAwGTEXMBUGA1UEAwwOUm9vdCBTZXJ2ZXIgQ0EwHhcNMjIwMTA2MTY0MzA5WhcN\nMjIwMjA1MTY0MzA5WjAZMRcwFQYDVQQDDA5Sb290IFNlcnZlciBDQTCCASIwDQYJ\nKoZIhvcNAQEBBQADggEPADCCAQoCggEBAKKcTJ+DYLpFWVPcKFzu+O205SNULgJ7\ngAnBpwezFWVUgolf1rsvBX5nS8kXi7kVN5xGBE5cVuI3yqTtIdjpMi5Nt0vznAFl\n3pEf/P4rt6BqmzQiUBXaoWtEo0tMqC1eMxhQjLM80DQDxjzBcKsVwKLYGxGf0cPS\nXpn8A9yWuyoU8zMRcu18awUHOCr1Ugv+q/SjlLASrZs0l5sRQaaAqILVkcUeY1tN\ntyINELmvYtolDrlNVgijrMsRRCLHbOZgcBZMZsf8O9skLuKAVX89OvIz1NJoOcmi\nKHVvYP3YL5hsjWHvHIqixQC5AlRIG14AmYZjnNhZWJho8yPuQ5B/vrsCAwEAAaMT\nMBEwDwYDVR0TBAgwBgEB/wIBATANBgkqhkiG9w0BAQsFAAOCAQEAVcakPXtKjDSN\nlkre2xaYuYktTdeqgCkaR/533o17p+6k51Uz/yV4VhddaE6BYxiEsERVeC0lbO4a\noU5gsKapqpypxhzxqV/npMcN8l8zw8lh9jD7NCD3UN+0+Y2xufrvZEE3LH31hdL2\nNJ2xrzZohrY0a0PS9brlxNVgewUcsI6ldhxQN0tC4v4BYYrESrmDMXqL/cGbs+o9\n6GkNpjL38PXbitIBha7YV3VulfVutWLZEmVfmeoJjP3vpMh6x9wfuRefbZ2U4GM2\nhfJNWlEHt15qxlkF0gVTUn8jlr6f6Ww/o3UDSzfu6yLExj6ldnA4NGf58mqF5vFP\nDNY/2odaPw==\n-----END CERTIFICATE-----'"}"

  # Manual generation
  #
  # cd /home/circleci/
  # openssl req -x509 -newkey rsa:2048 -nodes -keyout /dev/null -out cert.pem -sha256 -days 1 -subj "/C=US/ST=Oregon/L=Portland/O=Company Name/OU=Org/CN=www.example.com"
  # export CIRCLECI=true
  # export BASH_ENV=/home/circleci/bash.env
  # cci-export CERT "$(cat cert.pem)"
  # cat /home/circleci/bash.env
  # source /home/circleci/bash.env
  # echo $CERT


  # v0.3.21
  # circleci@14f96ce78083:~$ cat /home/circleci/bash.env
  # export CERT=$'-----BEGIN CERTIFICATE-----\nMIIDwTCCAqmgAwIBAgIUdN9eK04EyAy4BG/12mh7B3gsXQkwDQYJKoZIhvcNAQEL\nBQAwcDELMAkGA1UEBhMCVVMxDzANBgNVBAgMBk9yZWdvbjERMA8GA1UEBwwIUG9y\ndGxhbmQxFTATBgNVBAoMDENvbXBhbnkgTmFtZTEMMAoGA1UECwwDT3JnMRgwFgYD\nVQQDDA93d3cuZXhhbXBsZS5jb20wHhcNMjIwMTA2MTczNTAxWhcNMjIwMTA3MTcz\nNTAxWjBwMQswCQYDVQQGEwJVUzEPMA0GA1UECAwGT3JlZ29uMREwDwYDVQQHDAhQ\nb3J0bGFuZDEVMBMGA1UECgwMQ29tcGFueSBOYW1lMQwwCgYDVQQLDANPcmcxGDAW\nBgNVBAMMD3d3dy5leGFtcGxlLmNvbTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCC\nAQoCggEBAMO321HK8A8ukhDaAgUpe9JzpjiheYV94yzRuyxW4E7/0s5EnFZ9Ws93\neSLJbMQN+TzLABYexhiCLZhBwrNdBKy6WztxODR8V2yrpO1sjiUpEgaUDjRUniFQ\ni+JbJpkCDYJhHVYfgABEJxhh4Uh0YYzP4BuO+mvOJNdBxnrZoIDyQhrStIZ4MM1V\nykhwtgGYflxOtbBHf7ioT6wdvQn9LdMuoFB0TGR7/T+FrecXA8Bz0lg7tWymrBCa\npzHMSzZBIcn4cY01ec9RRNxJfWtg7/M0SLtea9WmT9ZcVRxUggDrjhZC6U+rjNYK\n3rFobZU68Bmr0C2eTwld27f4tJPcSH0CAwEAAaNTMFEwHQYDVR0OBBYEFGxCydgA\nLxnSeYZlAU6tS+okgwTXMB8GA1UdIwQYMBaAFGxCydgALxnSeYZlAU6tS+okgwTX\nMA8GA1UdEwEB/wQFMAMBAf8wDQYJKoZIhvcNAQELBQADggEBALkAp3ngVKLrfqNE\nKtQ45zN3m87Y8RKRpFJRBvGoGkTH1ZI7Kcw/EBevPTDe8v3Qdgm1dLG4pmSpUvpR\nG09AF5gUwVmIFFtHrkYipLzZir/rwnrAZjVjW3d9CyvuEiZ2vVOM70nuAvAwNOpe\nvzFj4h3yXXN+4O0vLd6R2evUdAsqSOLXhAf3b+pm9WUItI9XQ0VtyT4P/WsNV6my\nrxwIAEhXSv2U/ScD8Tanc3Y1TNJ0kB2jzWpqg+Py1WENbGzgxaxmZgxlQNM8sOCG\nCiZUNqePNdhunGxum7/lLMYTyQxqcr263LE5fQZldEO1Isw1UgyoSxf/y/yl2OgM\nhQ2W/JY=\n-----END CERTIFICATE-----'
  # circleci@ae6a7a1ee93c:~$ source /home/circleci/bash.env
  # circleci@ae6a7a1ee93c:~$   echo $CERT
  # -----BEGIN CERTIFICATE----- MIIDwTCCAqmgAwIBAgIUMRXLdgoxz2EJUdQTAbTDtno3h18wDQYJKoZIhvcNAQEL BQAwcDELMAkGA1UEBhMCVVMxDzANBgNVBAgMBk9yZWdvbjERMA8GA1UEBwwIUG9y dGxhbmQxFTATBgNVBAoMDENvbXBhbnkgTmFtZTEMMAoGA1UECwwDT3JnMRgwFgYD VQQDDA93d3cuZXhhbXBsZS5jb20wHhcNMjIwMTA2MTc0NzA1WhcNMjIwMTA3MTc0 NzA1WjBwMQswCQYDVQQGEwJVUzEPMA0GA1UECAwGT3JlZ29uMREwDwYDVQQHDAhQ b3J0bGFuZDEVMBMGA1UECgwMQ29tcGFueSBOYW1lMQwwCgYDVQQLDANPcmcxGDAW BgNVBAMMD3d3dy5leGFtcGxlLmNvbTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCC AQoCggEBALBAoeNLBFTEtJlise8NVYHfpN1L+ATHm8UQN1qI2k+UASnCUj0nu3mW 9uuAvNHGmGRk8pKxw0/ViR3GCQfP4jDosN86oMCZysKsbVgfMtYSqYqgLZJ7469/ +P+u9KAxLH//k62pO+pHxpgBsQs8PGEHJBltYUXK7rnr5No+L+kM/TsLg82lJDVC TJl6h/DjIG2mpqoTqMPlo6oNLTjSRS4QqW1MhQ7BXegaPemlwiRw2myvzdoBkrPC v23PHCGq0EyXdqVT+eE/GWiVdOBrrd16O7U3e5CTSlw638n8Jxnt3vA6rOXxhiR8 NbXVdQnAXCJ4/UO2tWPttPVhPklPqfsCAwEAAaNTMFEwHQYDVR0OBBYEFO+vbaTE jYrwTroT60F7K7DJ4LvwMB8GA1UdIwQYMBaAFO+vbaTEjYrwTroT60F7K7DJ4Lvw MA8GA1UdEwEB/wQFMAMBAf8wDQYJKoZIhvcNAQELBQADggEBADePakFX7O9Aq3Sn sBvoHyBCCuR4Q/sJwyi7gwrWi1nhC+tXdXIFcbo3Ub/A1hem6gDiNAZzrfuMo90a IRrAksihrrRJj9L8a7005w2tqTnFdB6fgScyzPCeAHJ+1P6FNbbCyOTxzdrysVqg DcbCutoF5ZXkdhOzY4hXoA7N4MM1qEwEKgsanM4zh6cGiDZG0AOZKAT+EAWdqaZ4 gY+Hq+Bn3YTjWA+N0x5zhB+NJcOIMPiP13yHc9E9EWrj6sYBOGR0q6vfgYJslDnh ue2h4Ot9YMToo1zpMMYrXS3HyhIltqvgW2dF2vq6U6tCuIBLaAze9KrHPBxodVYk jZv8N5c= -----END CERTIFICATE-----
  # circleci@ae6a7a1ee93c:~$

  # v0.3.22
  # circleci@075450e32cf6:~$ cat /home/circleci/bash.env
  # export CERT="${CERT:-"$'-----BEGIN CERTIFICATE-----\nMIIDwTCCAqmgAwIBAgIUD0inamIx2PKg3yfAkkhvCh3h98QwDQYJKoZIhvcNAQEL\nBQAwcDELMAkGA1UEBhMCVVMxDzANBgNVBAgMBk9yZWdvbjERMA8GA1UEBwwIUG9y\ndGxhbmQxFTATBgNVBAoMDENvbXBhbnkgTmFtZTEMMAoGA1UECwwDT3JnMRgwFgYD\nVQQDDA93d3cuZXhhbXBsZS5jb20wHhcNMjIwMTA2MTc0NDEyWhcNMjIwMTA3MTc0\nNDEyWjBwMQswCQYDVQQGEwJVUzEPMA0GA1UECAwGT3JlZ29uMREwDwYDVQQHDAhQ\nb3J0bGFuZDEVMBMGA1UECgwMQ29tcGFueSBOYW1lMQwwCgYDVQQLDANPcmcxGDAW\nBgNVBAMMD3d3dy5leGFtcGxlLmNvbTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCC\nAQoCggEBAMKx06QhzVe/VYwpD2+/HnYeiyydbgk/K2I8cTmN158JZDwdTp1va0H8\nxdN0HVaBWgg9523ezKVbSn22za1keaOtqAcf1TRw8scp8JRnXNHQgbCbAQwRTi93\nUaC6WB50vOTIW887vWpm3pEh041vYBwEIp7oPy7kG+499Imo9OZY/W+NtKLPgVjn\nA5SoqjGoh/rbJTSNPyvxXszY0DPaauqzsuGSCXCWc3yNZA5gXuAR9+zq/HO81LCR\nkC2pkAMFQf1ARgRNWWMav9tDyqe455wub0GYXQLy6KioKzCPNc3u891OYTbO4SCk\n5Ljc9RcrzVKCqFOO1bLN2wmg30IOPycCAwEAAaNTMFEwHQYDVR0OBBYEFL1TN+ra\n83QpJeEoJ+AFfvYFl2rpMB8GA1UdIwQYMBaAFL1TN+ra83QpJeEoJ+AFfvYFl2rp\nMA8GA1UdEwEB/wQFMAMBAf8wDQYJKoZIhvcNAQELBQADggEBAIzI0KORcIGuuxET\niIpiVECKuPWjXjtmbfyQNYRg3aDsLZXRYQPrswaIMIm0tDLgGh2PsieRJdaYcYdX\nG2DJov0ebvnU/v1q0vhEtpWJ/3P3zpuCPK17BM+hjoBV4/roPo2lQ1R7lyfpxa0J\nQfLZwYa7nFEA+g0aK/7UHmtttkuVoemOm5W5hM9JTpla45Gw2JUqnMGQnQFokfEv\nkgenCzysmLr4rOV2jze5NZTbshrxJ+aj3LYrT92ejYFNEX0Y3mCBIv0J9n3lh3Ed\n3XR2BOpMP7VE8eJJ8QAsqYH7lgQuxwto8W2CvuSZ7FWc9KVy9tC8p4Lp6lwUKPL2\nk+U/43w=\n-----END CERTIFICATE-----'"}"
  # circleci@075450e32cf6:~$ source /home/circleci/bash.env
  # circleci@075450e32cf6:~$ echo $CERT
  # -----BEGIN CERTIFICATE----- MIIDwTCCAqmgAwIBAgIUD0inamIx2PKg3yfAkkhvCh3h98QwDQYJKoZIhvcNAQEL BQAwcDELMAkGA1UEBhMCVVMxDzANBgNVBAgMBk9yZWdvbjERMA8GA1UEBwwIUG9y dGxhbmQxFTATBgNVBAoMDENvbXBhbnkgTmFtZTEMMAoGA1UECwwDT3JnMRgwFgYD VQQDDA93d3cuZXhhbXBsZS5jb20wHhcNMjIwMTA2MTc0NDEyWhcNMjIwMTA3MTc0 NDEyWjBwMQswCQYDVQQGEwJVUzEPMA0GA1UECAwGT3JlZ29uMREwDwYDVQQHDAhQ b3J0bGFuZDEVMBMGA1UECgwMQ29tcGFueSBOYW1lMQwwCgYDVQQLDANPcmcxGDAW BgNVBAMMD3d3dy5leGFtcGxlLmNvbTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCC AQoCggEBAMKx06QhzVe/VYwpD2+/HnYeiyydbgk/K2I8cTmN158JZDwdTp1va0H8 xdN0HVaBWgg9523ezKVbSn22za1keaOtqAcf1TRw8scp8JRnXNHQgbCbAQwRTi93 UaC6WB50vOTIW887vWpm3pEh041vYBwEIp7oPy7kG+499Imo9OZY/W+NtKLPgVjn A5SoqjGoh/rbJTSNPyvxXszY0DPaauqzsuGSCXCWc3yNZA5gXuAR9+zq/HO81LCR kC2pkAMFQf1ARgRNWWMav9tDyqe455wub0GYXQLy6KioKzCPNc3u891OYTbO4SCk 5Ljc9RcrzVKCqFOO1bLN2wmg30IOPycCAwEAAaNTMFEwHQYDVR0OBBYEFL1TN+ra 83QpJeEoJ+AFfvYFl2rpMB8GA1UdIwQYMBaAFL1TN+ra83QpJeEoJ+AFfvYFl2rp MA8GA1UdEwEB/wQFMAMBAf8wDQYJKoZIhvcNAQELBQADggEBAIzI0KORcIGuuxET iIpiVECKuPWjXjtmbfyQNYRg3aDsLZXRYQPrswaIMIm0tDLgGh2PsieRJdaYcYdX G2DJov0ebvnU/v1q0vhEtpWJ/3P3zpuCPK17BM+hjoBV4/roPo2lQ1R7lyfpxa0J QfLZwYa7nFEA+g0aK/7UHmtttkuVoemOm5W5hM9JTpla45Gw2JUqnMGQnQFokfEv kgenCzysmLr4rOV2jze5NZTbshrxJ+aj3LYrT92ejYFNEX0Y3mCBIv0J9n3lh3Ed 3XR2BOpMP7VE8eJJ8QAsqYH7lgQuxwto8W2CvuSZ7FWc9KVy9tC8p4Lp6lwUKPL2 k+U/43w= -----END CERTIFICATE-----
  # circleci@075450e32cf6:~$
}

@test "cci-export sanity check many values" {
  run cat "${_FILE}"
  assert_output "1.2.3"

  export VAR=placeholder
  run cci-export VAR1 "text/$VAR/text:$(cat "${_FILE}")"
  run cci-export VAR2 "text/$VAR/text:$(cat "${_FILE}")"
  run cci-export IMAGE3 "text/$VAR/text:$(cat "${_FILE}")"

  run "$HOME/test/foo-printer.sh" "VAR1"
  assert_output "VAR1: text/$VAR/text:$(cat "${_FILE}")"
  assert_output "VAR1: text/placeholder/text:1.2.3"

  run "$HOME/test/foo-printer.sh" VAR2
  assert_output "VAR2: text/$VAR/text:$(cat "${_FILE}")"
  assert_output "VAR2: text/placeholder/text:1.2.3"

  run "$HOME/test/foo-printer.sh" IMAGE3
  assert_output "IMAGE3: text/$VAR/text:$(cat "${_FILE}")"
  assert_output "IMAGE3: text/placeholder/text:1.2.3"
}

@test "cci-export potentially colliding variable names" {
  run cci-export PART1 "value1"
  run cci-export PART1_PART2 "value_joined"
  run cci-export PART1 "value2"

  run "$HOME/test/foo-printer.sh" PART1
  assert_output "PART1: value2"
  refute_output "PART1: value1"
  run "$HOME/test/foo-printer.sh" PART1_PART2
  assert_output "PART1_PART2: value_joined"
}

@test "exported variable should be respected in a script" {
  export FOO=bar
  run "$HOME/test/foo-printer.sh"
  assert_output "FOO: bar"
  refute_output "FOO: "
}

@test "shadowed variable should be respected in a script" {
  FOO=bar run "$HOME/test/foo-printer.sh"
  assert_output "FOO: bar"
  refute_output "FOO: "
}

@test "exported variable should have priority over the cci-exported one" {
  run cci-export FOO cci
  export FOO=bar
  run "$HOME/test/foo-printer.sh"
  assert_output "FOO: bar"
  refute_output "FOO: cci"
  refute_output "FOO: "
}

@test "shadowed variable should have priority over the cci-exported one" {
  run cci-export FOO cci
  FOO=bar run "$HOME/test/foo-printer.sh"
  assert_output "FOO: bar"
  refute_output "FOO: cci"
  refute_output "FOO: "
}

@test "shadowed variable should have priority over both: the exported and the cci-exported one" {
  export FOO=bar-export
  run cci-export FOO cci
  FOO=bar-shadow run "$HOME/test/foo-printer.sh"
  assert_output "FOO: bar-shadow"
  refute_output "FOO: bar-export"
  refute_output "FOO: cci"
  refute_output "FOO: "


  run cci-export FOO cci2
  export FOO=bar-export2
  FOO=bar-shadow2 run "$HOME/test/foo-printer.sh"
  assert_output "FOO: bar-shadow2"
  refute_output "FOO: bar-export2"
  refute_output "FOO: cci2"
  refute_output "FOO: "
}
