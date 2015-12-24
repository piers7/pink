pink====Pink (the PowerShell INstall Kit) is a set of PowerShell scripts / script modules to assist in creating **environment-neutral, installable packages** from many common Microsoft project types, **particularly BI / BIDS types** (SSDT, SSAS, SSRS, SSIS etc...). These are scripts I've accumulated over the last 10 years or so, but I've attempted to make sure they've all been cleaned up prior to adding to this project.Pink started life principally targeting creating zip files containing artefacts + install scripts, but these days I use nugets as the container format, and tools such as [Octopus Deploy](http://octopusdeploy.com) for the distribution. That being said neither of these is a requirement - zip / xcopy deployments are still fine.Philosophy--A common deployment process for many projects, sadly prevalent in BI teams, is the 'right click / deploy' pattern. This has a number of significant issues:- No control that deployed artefacts match current source control version, or even that they've have _ever_ been checked in at all- Not necessarily repeatable - results can vary depending on setup of machine used to build/deploy, versions of toolset installed, Visual Studio PrivateAssemblies folders and so forth- Either requires developers to have elevated (admin) rights on production, or- Requires Operations / Admins to open Visual Studio, build the project then deploy themselvesThe solution to this is to use a server-side build process to create your installation artefacts, and to embed those artefacts in some kind of deployment package that install itself. This enables repeatability, and allows for separation of administrative responsibilities. You _can_ use an MSI for this kind of stuff, but it becomes hard to incorporate configuration that needs to change at deploy time (server names that vary across dev/test/prod environments).The philosophy behind pink is to enable you to produce **environment-neutral installable packages**, where your install process primarily uses PowerShell scripting.Build Scripts--Pink is *primarily* a set of install scripts, however it also incorporates a number of *build* scripts to help you get your artefacts in the right shape in the first place. For example building SSAS, SSRS, SSIS projects without shelling out to devenv. It also includes some version-number rolling scripts, and some useful functions for managing service messages within TeamCity builds.Install Scripts--Cmdlets to help:- Deployment of SSDT databases, SSAS, SSIS, SSRS projects