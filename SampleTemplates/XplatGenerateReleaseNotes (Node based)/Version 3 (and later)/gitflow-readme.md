# GitFlow & Azure Wiki Template
This template is intended to be used for those who follow GitFlow; it is one template with 3 segments - development, testing, and production. Each section produces information most relevant to those involved in the stage's process (i.e. devs read development, QA reads testing, product owners read production).

## Linking
The template makes an effort to link _every_ possible element possible. Work items, build history, release history, tests ran, user profiles for commits, PRs, PR **reviewers**, etc.

### Azure DevOps Wiki
This template makes heavy use of some nice linking features from the Azure DevOps wiki. For instance, `#123` will link to the WorkItem of ID: 123, and `!123` will link to a PR with ID: 123. It is possible to remove this dependency and replace it with static data, but you will lose some of the dynamic updates linking provides.

## Supporting GitFlow
GitFlow has a release cycle that looks something like the following:
```
---DEV----DEV-----DEV------DEV--------DEV------------------------
------\----------------------------------\-----------------------
-------TEST-------------------------------TEST------TEST---------
-----------\--------------------------------------------\--------
------------PROD------------------------------------------PROD---
```

This template supportd this process by creating release notes based on the _current version_ of the release cycle.  
For instance, you can release DEV five times on version `1.5.2`, TEST twice, and PROD once. Since the version of ecah of these is the same (after releasing `1.5.3` the next commit on DEV becomes 1.6.0 or 1.5.4), we can continually _prepend_ each section, building up a rich history or releases to each environment.

## Custom Helpers
There is a single Handlebars Helper necessary here, which is used to allow the pipeline to define whether to render a development, testing, or production template.

## Custom Fields
This template makes use of 3 custom fields. Bugs and PBIs have a field called "Release Notes" which allows the generation of a high-level Release Notes section in the production template. Bugs alone have two fields called "Expected Results" and "Actual Results". This helps QA in TEST identify the issue, and the intended functionality.

## Result
_Note: It is expected there will be more than one iteration of the release and development templates_
![image](https://user-images.githubusercontent.com/6847381/86543077-5a4eea00-bee9-11ea-927c-228d4878afbc.png)