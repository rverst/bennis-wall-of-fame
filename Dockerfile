# build the upload page
FROM node:lts as up-builder
WORKDIR /app

COPY ./bwof-upload-page/package.json .
COPY ./bwof-upload-page/yarn.lock .
RUN yarn install

COPY ./bwof-upload-page/. .
RUN yarn build

# build the viewer page
FROM node:lts as vp-builder
WORKDIR /app

COPY ./bwof-viewer-page/package.json .
COPY ./bwof-viewer-page/yarn.lock .
RUN yarn install

COPY ./bwof-viewer-page/. .
RUN yarn build

# build the backend
FROM golang:1.14-alpine as go-builder

# install dependencies
RUN apk update && apk add --no-cache git ca-certificates tzdata && update-ca-certificates

# create unprivileged user
RUN adduser -D -g '' appuser

WORKDIR  /app
COPY ./bwof-backend/. .

RUN GOOS=linux GOARCH=amd64 go build -ldflags="-w -s" -o ./build/server ./cmd/server/main.go

# combine all to one app

FROM alpine

COPY ./public/. /app/public/.

# import from buider
COPY --from=go-builder /usr/share/zoneinfo /usr/share/zoneinfo
COPY --from=go-builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=go-builder /etc/passwd /etc/passwd

COPY --from=go-builder /app/build/server /app/server
COPY --from=up-builder /app/build/. /app/public/uploader
COPY --from=vp-builder /app/build/. /app/public/viewer

USER appuser

EXPOSE 8000
VOLUME data
ENV DATA=/data

ENTRYPOINT ["/app/server"]

