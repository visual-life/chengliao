# Security Policy

## Reporting a vulnerability

Please do not publish credentials, personal data, or exploit details in a public issue. Contact the repository owner privately through their GitHub profile instead.

## Secrets

This repository does not require committed credentials. Copy `.env.example` to `.env`, choose strong local passwords, and keep `.env` untracked. If a credential is ever committed or shared, revoke or rotate it immediately; deleting the file alone is not sufficient.

## Production use

The project is an early-stage chat application. Before exposing it to the public internet, add authentication and authorization, restrict CORS, validate upload types, apply rate limits, use HTTPS, and configure a TURN service for WebRTC.
