# Releasing

How a release is made and what has to exist for it. The flow itself is in `AGENTS.md` ("How work flows").

## The release pull request
1. The open milestone `vX.Y.Z → next` has no open issue: each one is done, or closed as not planned, or moved to the
   next milestone, with the reason written in it.
2. The team decides the number from what the release contains (`AGENTS.md`), and someone opens the pull request
   from `next` into `main` titled `vA.B.C: <what a player gets>`, with the notes `python tools/dev/release-notes.py`
   prints as its body.
3. `release-guard.yml` checks it: from `next`, a version above the last tag, nothing open in the milestone, the change
   notes well formed. A person merges it.
4. `release.yml` then tags it, builds the web game with that version, publishes it to Firebase Hosting, writes the
   GitHub release, closes the milestone as `vX.Y.Z → vA.B.C`, opens `vA.B.C → next`, and brings `next` up to date.

## Publishing without a stored key (set once)
GitHub publishes to Firebase through Workload Identity Federation: on each run GitHub hands Google a short-lived,
signed statement of which repository is running, and Google lets only this repository act as one service account
that may deploy Firebase Hosting. No key exists to leak. The same pool can serve other repositories of the same owner
by adding one binding each. Set up once by a person logged in to Google Cloud (`gcloud auth login`) with rights on
the Firebase project `aklabs-dev` (project number 11340527725):

```
P=aklabs-dev; N=11340527725; SA=fh-forever-deploy@$P.iam.gserviceaccount.com
REPO=alexanderkholodov1/farpoint-horizon-forever
gcloud iam workload-identity-pools create github --project=$P --location=global --display-name="GitHub Actions"
gcloud iam workload-identity-pools providers create-oidc github --project=$P --location=global \
  --workload-identity-pool=github --issuer-uri=https://token.actions.githubusercontent.com \
  --attribute-mapping="google.subject=assertion.sub,attribute.repository=assertion.repository" \
  --attribute-condition="assertion.repository_owner=='alexanderkholodov1'"
gcloud iam service-accounts create fh-forever-deploy --project=$P --display-name="Farpoint HORIZON Forever deploy"
gcloud projects add-iam-policy-binding $P --member=serviceAccount:$SA --role=roles/firebasehosting.admin
gcloud iam service-accounts add-iam-policy-binding $SA --project=$P --role=roles/iam.workloadIdentityUser \
  --member="principalSet://iam.googleapis.com/projects/$N/locations/global/workloadIdentityPools/github/attribute.repository/$REPO"
gh variable set WIF_PROVIDER -R $REPO --body "projects/$N/locations/global/workloadIdentityPools/github/providers/github"
gh variable set WIF_SERVICE_ACCOUNT -R $REPO --body "$SA"
```

The service account may deploy every hosting site of `aklabs-dev`; `firebase.json` names this game's site
(`farpoint-horizon-forever`), so a deploy from here never touches another site.

## Firebase's free limits
Hosting on the free plan allows 360 MB of transfer per day for the whole project, and a first visit to the game
downloads about 56 MB (measured 2026-11-16). The `next` preview and production share that budget; issue #11 measures
the limits and fixes the ones a player could hit.
