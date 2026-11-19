# Changelog

## [0.3.3](https://github.com/pelotech/terraform-aws-account-bootstrap/compare/v0.3.2...v0.3.3) (2026-11-19)


### Chores

* **deps:** update pre-commit hook antonbabenko/pre-commit-terraform to v1.109.5 ([#21](https://github.com/pelotech/terraform-aws-account-bootstrap/issues/21)) ([b2c7277](https://github.com/pelotech/terraform-aws-account-bootstrap/commit/b2c72777023f6ba29560900befde6b8f30203391))
* **renovate:** group github actions minor and patch updates into one pr ([#23](https://github.com/pelotech/terraform-aws-account-bootstrap/issues/23)) ([357339a](https://github.com/pelotech/terraform-aws-account-bootstrap/commit/357339aeb07d6b3bd26125508dd2a0533efa6e46))

## [0.3.2](https://github.com/pelotech/terraform-aws-account-bootstrap/compare/v0.3.1...v0.3.2) (2026-11-17)


### Refactors

* move risk alerts to terraform-aws-organization ([#19](https://github.com/pelotech/terraform-aws-account-bootstrap/issues/19)) ([cf7c8c4](https://github.com/pelotech/terraform-aws-account-bootstrap/commit/cf7c8c40b6c502b69b2aed63ef592c6125e1012a))

## [0.3.1](https://github.com/pelotech/terraform-aws-account-bootstrap/compare/v0.3.0...v0.3.1) (2026-11-16)


### Bug Fixes

* reject risk_alerts webhook_urls in govcloud at plan time ([#17](https://github.com/pelotech/terraform-aws-account-bootstrap/issues/17)) ([0a6ab14](https://github.com/pelotech/terraform-aws-account-bootstrap/commit/0a6ab14fdb31bf3e21c2551e01b7dcdab7b4839d))

## [0.3.0](https://github.com/pelotech/terraform-aws-account-bootstrap/compare/v0.2.0...v0.3.0) (2026-11-16)


### Features

* optional AWS Health RISK alerts by email and chat webhook ([#15](https://github.com/pelotech/terraform-aws-account-bootstrap/issues/15)) ([17e87a0](https://github.com/pelotech/terraform-aws-account-bootstrap/commit/17e87a0c952dedcf736c0993fac61355fd180363))


### Chores

* **deps:** update lint tooling ([#13](https://github.com/pelotech/terraform-aws-account-bootstrap/issues/13)) ([03c5fb9](https://github.com/pelotech/terraform-aws-account-bootstrap/commit/03c5fb9ca2fdaa9e0be3932fb19f2bdf6b6adaa7))

## [0.2.0](https://github.com/pelotech/terraform-aws-account-bootstrap/compare/v0.1.1...v0.2.0) (2026-11-09)


### Features

* accept owner and repo IDs in github.repository ([#11](https://github.com/pelotech/terraform-aws-account-bootstrap/issues/11)) ([a1e7819](https://github.com/pelotech/terraform-aws-account-bootstrap/commit/a1e78192046685f6df3f1391d88a7607f5aced13))

## [0.1.1](https://github.com/pelotech/terraform-aws-account-bootstrap/compare/v0.1.0...v0.1.1) (2026-11-09)


### Bug Fixes

* avoid deprecated managed_policy_arns warning on management roles ([#9](https://github.com/pelotech/terraform-aws-account-bootstrap/issues/9)) ([b35893f](https://github.com/pelotech/terraform-aws-account-bootstrap/commit/b35893f2135f27958212466208e014d859073d3b))

## 0.1.0 (2026-11-09)


### Features

* initial release ([#6](https://github.com/pelotech/terraform-aws-account-bootstrap/issues/6)) ([ccd4356](https://github.com/pelotech/terraform-aws-account-bootstrap/commit/ccd43562d67fff4ab3252045aa4f50f36dccbaf7))


### Chores

* **deps:** update lint tooling ([#7](https://github.com/pelotech/terraform-aws-account-bootstrap/issues/7)) ([ca29fac](https://github.com/pelotech/terraform-aws-account-bootstrap/commit/ca29facfd67303def9daddcf05f0238047546390))
* initial commit ([0612504](https://github.com/pelotech/terraform-aws-account-bootstrap/commit/061250481ec21e4a7d67cea48fa443c140329ffc))
* install terraform with tenv instead of building it with nix ([#8](https://github.com/pelotech/terraform-aws-account-bootstrap/issues/8)) ([51fed8f](https://github.com/pelotech/terraform-aws-account-bootstrap/commit/51fed8f18750ec856acc584859181239500d5051))
