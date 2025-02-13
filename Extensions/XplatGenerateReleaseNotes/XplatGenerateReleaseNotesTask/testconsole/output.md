# Notes for build 
**Build Number**: 185639
**Build Trigger PR Number**:  

# Associated Pull Requests (3)
### Associated Pull Requests (only shown if  PR) 
*  **PR **  #141139 - DB And Service changes required for the new Summary field in Use of Force.

*  **PR **  #141139 - Add Use of Force summary template management into the portal

*  **PR **  Add tuServ.MAUI demand

# Global list of WI (2)
## Associated Work Items (only shown if  WI) 
*  **141239**  Engineering - Fix MAUI build demands to route to correct agent
  - **WIT** Bug 
  - **Tags** Builds; Engineering
  - **Assigned**  Adam Ansell 

*  **141139**  Use of Force Changes - Service Changes
  - **WIT** Product Backlog Item 
  - **Tags** 
  - **Assigned**  Leon Nightingale 

# Global list of CS (20)
### Associated commits  (only shown if CS) 
* ** ID9874b44a0cfdbff37a47fcfdabe2918089de1edd** 
  -  **Message:** Wire up the use of force process to support templates and create a default blank template to use while testing.
  -  **Commited by:** Leon Nightingale 

* ** ID33f5ac8b50af5750e14b0f63512c1722918581d4** 
  -  **Message:** Fix the enum / string now common has been updated.
  -  **Commited by:** Leon Nightingale 

* ** ID54e24f0b2e230a874ff17ceb4c32a3017bbc05c6** 
  -  **Message:** Update the integration tests to ensure we populate the new process template for Use of Force and remove the SonarQube warnings from the related integration tests.
  -  **Commited by:** Leon Nightingale 

* ** ID3479bb53a738c6bddce50dafbc63070f5ebf7d1e** 
  -  **Message:** Add unit tests to the portal to ensure the results from the GetTemplateTypeValues method are correct.
  -  **Commited by:** Leon Nightingale 

* ** IDc3c6b4e7d2d3c0f79847f4d382c47db43ccd2b32** 
  -  **Message:** Change the ever increasing if statement to a switch statement. This should make it easier to follow as more gets added.
  -  **Commited by:** Leon Nightingale 

* ** IDbbeaf53edbb0240c9cfbccf02f82d072871e89cb** 
  -  **Message:** Ensure the custom process detail page gets updated when the user navigates back into the page.
  -  **Commited by:** Leon Nightingale 

* ** IDfa4f6b2cad0ca67a018afba517d85fa457d133af** 
  -  **Message:** Update the navigation logic to enforce the event handler is removed when the scope is destroyed (by navigation away using the nav menu for example).
  -  **Commited by:** Leon Nightingale 

* ** IDbc6bb970bce8862f8aa50a73f0e9fd52b6420def** 
  -  **Message:** Only show the Mandatory Fields Enabled control when the template type is Statement, as this is the only type that requires this field.
  -  **Commited by:** Leon Nightingale 

* ** ID6ed516813bf5a5d0bac63f373a2c3b04323900ab** 
  -  **Message:** Update the Stop Search service to handle submitting and retrieving the new Summary field to be used on Use of Force.
  -  **Commited by:** Leon Nightingale 

* ** ID67e60d9396ff3eeeb61f375b599be9b007595840** 
  -  **Message:** Add the summary field mapping for the Use of Force summary field within the submission and record services. This has included quite a lot of SonarQube warning fixes.
  -  **Commited by:** Leon Nightingale 

* ** IDf9ca17bfc893c37effa04b12e2910b412100f988** 
  -  **Message:** Change how the Logger is passed into the Template controller to see if that fixes the unit tests on the build server.
  -  **Commited by:** Leon Nightingale 

* ** ID395b844f4b4f3ac8b1da1a2e451ec141bae149a7** 
  -  **Message:** Change the order in whihc the Feature Flag ervice is initialised to ensure the tests pass without needing AppInights
  -  **Commited by:** Leon Nightingale 

* ** ID7d0161077f76a95cb5e6eb062ead2b0269e36036** 
  -  **Message:** Fix some minor bits and pieces on the Use of Force tests.
  -  **Commited by:** Leon Nightingale 

* ** ID514f917dd531c5b9c388ddcdc7e0ebbb3a2468ca** 
  -  **Message:** A couple of bits of tidy up after demoing to Darja.
  -  **Commited by:** Leon Nightingale 

* ** ID11de1c30c7cbe3ef9c46642f797e1cd596b228e5** 
  -  **Message:** Fix the message in the assert for the unit test.
  -  **Commited by:** Leon Nightingale 

* ** IDee309dabf44f94e54204bdb80d5977c719da5303** 
  -  **Message:** Merged PR 12078: #141139 - DB And Service changes required for the new Summary field in Use of Force.

## What has changed and why?
### Areas affected
&gt; Please check one or more that apply

**Core tuServ**
- [ ] Client
- [x] Core Services Solution

**tuServ Records**
- [x] Stop Search Service

**Integration**
- [ ] PNC Facade
- [ ] PentiP Facade
- [ ] BizTalk

**Tools**
- [ ] Tools

**Other**
- [ ] Other

### PR summary
&gt; Please provide a description below of the changes made. Include information on the specific components affected (for example, which databases have been changed).

- Update the Stop Search service to handle submitting and retrieving the new Summary field to be used on Use of Force.
- Add the summary field mapping for the Use of Force summary field within the submission and record services. This has included quite a lot of SonarQube warning fixes.

## Are there any breaking changes?
- [x] Contains **NO** breaking changes

&gt; If a breaking change has been made, please provide a detailed description below of the impact and the migration path.

## What testing has been done?
- [ ] Run manual tests
- [x] Automated (Unit, Integration etc.) tests have been added/updated and pass
&gt; Please provide a description below of the testing that has been completed. If automated tests have not been added, please provide a reason why.

Added tests to check the field mapping.

## Are there any configuration changes?
- [ ] Has there been any configuration changes?
&gt; If new feature flags have been added or configuration files have been updated, please provide the link to the PR from tuServ Install below.

## Documentation
- [ ] Has any wiki documentation been added?

## References
&gt; Please provide any additional references below that are relevant to the changes made (i.e. another work item, existing PR)

Related work items: #141139
  -  **Commited by:** Leon Nightingale 

* ** ID3f7a7e0dd248e882e6e65eb1129cbbaf18a3d5fc** 
  -  **Message:** Merged PR 12072: #141139 - Add Use of Force summary template management into the portal

## What has changed and why?
### Areas affected
&gt; Please check one or more that apply

**Core tuServ**
- [ ] Client
- [x] Core Services Solution

**tuServ Records**
- [ ] Stop Search Service

**Integration**
- [ ] PNC Facade
- [ ] PentiP Facade
- [ ] BizTalk

**Tools**
- [ ] Tools

**Other**
- [ ] Other

### PR summary
&gt; Please provide a description below of the changes made. Include information on the specific components affected (for example, which databases have been changed).

Update the Use of Force process within the management portal and process settings database to allow templates to be managed from the process page.

As part of this work, I have slightly changed how the navigation between the &#x60;Process&#x60; page and the &#x60;Process Template&#x60; page to ensure the go back / save navigation works correctly from the &#x60;Process Template&#x60; page. And wired in the &#x60;pageshow&#x60; event on the process template page to ensure the page refreshes with any changes made to the process templates. The &#x60;Enabled mandatory fields&#x60; control is also hidden from template types other than &#x60;Statement&#x60; since this is the only process that uses it.

## Are there any breaking changes?
- [x] Contains **NO** breaking changes

&gt; If a breaking change has been made, please provide a detailed description below of the impact and the migration path.

## What testing has been done?
- [x] Run manual tests
- [x] Automated (Unit, Integration etc.) tests have been added/updated and pass
&gt; Please provide a description below of the testing that has been completed. If automated tests have not been added, please provide a reason why.

Deployed the database changes to my local environment to check the everything is working as expected.
Tidied up the existing integration tests around Process Templates and added some unit tests for the portal end points.
Tested the management portal changes on my local environment.

## Are there any configuration changes?
- [ ] Has there been any configuration changes?
&gt; If new feature flags have been added or configuration files have been updated, please provide the link to the PR from tuServ Install below.

## Documentation
- [ ] Has any wiki documentation been added?

## References
&gt; Please provide any additional references below that are relevant to the changes made (i.e. another work item, existing PR)

Related work items: #141139
  -  **Commited by:** Leon Nightingale 

* ** IDebf2b51407524fefaffa5cbf6b43cbe27c3c16e8** 
  -  **Message:** Add tuServ.MAUI demand
  -  **Commited by:** Adam Ansell 

* ** ID4d7224190631c552cb3f2049808c91dcb225cafc** 
  -  **Message:** Update demand
  -  **Commited by:** Adam Ansell 

* ** ID07a12cf039665e5fc4f4c5a7d538e6fb144dbfda** 
  -  **Message:** Merged PR 12086: Add tuServ.MAUI demand

## What has changed and why?
### Areas affected
&gt; Please check one or more that apply

**Core tuServ**
- [ ] Client
- [ ] Core Services Solution

**tuServ Records**
- [ ] Stop Search Service

**Integration**
- [ ] PNC Facade
- [ ] PentiP Facade
- [ ] BizTalk

**Tools**
- [ ] Tools

**Other**
- [x] Other

Build pipeline

### PR summary
&gt; Please provide a description below of the changes made. Include information on the specific components affected (for example, which databases have been changed).

## Are there any breaking changes?
- [x] Contains **NO** breaking changes

&gt; If a breaking change has been made, please provide a detailed description below of the impact and the migration path.

## What testing has been done?
- [ ] Run manual tests
- [ ] Automated (Unit, Integration etc.) tests have been added/updated and pass
&gt; Please provide a description below of the testing that has been completed. If automated tests have not been added, please provide a reason why.

## Are there any configuration changes?
- [ ] Has there been any configuration changes?
&gt; If new feature flags have been added or configuration files have been updated, please provide the link to the PR from tuServ Install below.

## Documentation
- [ ] Has any wiki documentation been added?

## References
&gt; Please provide any additional references below that are relevant to the changes made (i.e. another work item, existing PR)

Add tuServ.MAUI demand

Related work items: #141239
  -  **Commited by:** Adam Ansell 
