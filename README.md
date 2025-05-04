# Site Reliability Engineer Challenge

Welcome to the Personio SRE coding challenge. Read over the whole document before proceeding.

The rules:

- We are not here to trick you
- Contact us if you get stuck or have any clarifying questions
- Do not spend more than **four hours** on this challenge, less is better

The goals of the challenge are:

- For you, to showcase your skills
- For us, to check if your logic, knowledge, and adaptability match our expectations

## What should you do?

Create a production-ready infrastructure, which runs a Golang application bundled with this challenge.

Your solution should be based on the following criteria:

- Usage of AWS infrastructure
- Usage of the best suited tool(s) whenever possible
- Usage of Kubernetes for cluster management and application deployment

## Requirements

- All resources must be managed in code
- Keep the solution simple, but apply best practices where you see a fit for them

## Deliverables

Share us your _private_ GitHub / GitLab / Other repository where you implemented the solution.

The project should include (at least) the following files:

- Infrastructure-as-Code files for configuring the AWS infrastructure needed to run the application
- Manifest files which describe resources for the application deployment (e.g. k8s manifests)
- File clarifying your chosen approach. The following points should be included:
  - Overview of the infrastructure design
  - Description of how you would setup a CI/CD pipeline for this project
    - Describe how each of the necessary deployment steps works
    - Describe how you would rollback to a previously deployed version of the application
  - Further improvements that you would implement when continuing to work on the project

## What we look at when checking out your solution

- Quality of documentation and analysis
- Simplicity of the automated infrastructure
- Production-ready state

### Good luck
