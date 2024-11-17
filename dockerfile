FROM debian:bookworm-slim AS deps-stage

	WORKDIR /src

	RUN apt-get update \
		&& apt-get install --yes \
			unzip \
			wget \
			libtool \
			libz-dev \
			gcc-aarch64-linux-gnu

FROM deps-stage as get-source-stage

	ENV SQLITE_SOURCE_ZIP_URL="https://system.data.sqlite.org/blobs/1.0.119.0/sqlite-netFx-source-1.0.119.0.zip"

	WORKDIR /src

	RUN wget -O sqlite-source.zip "$SQLITE_SOURCE_ZIP_URL" \
		&& unzip sqlite-source.zip

	RUN chmod +x ./Setup/*.sh

FROM get-source-stage as build-interop-stage

	WORKDIR /src/Setup

	RUN sed -i 's|gcc -g -fPIC|aarch64-linux-gnu-gcc -g -fPIC|g' ./compile-interop-assembly-release.sh
	RUN ./compile-interop-assembly-release.sh

	RUN file /src/bin/2013/Release/bin/SQLite.Interop.dll \
		&& file /src/bin/2013/Release/bin/libSQLite.Interop.so \
		&& ldd --version

FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build-managed-stage

	WORKDIR /src

	COPY --from=get-source-stage /src ./

	WORKDIR /src/Setup
	RUN ./build-netstandard21-release.sh

FROM scratch as export-stage

	COPY --from=build-interop-stage /src/bin/2013/Release/bin/SQLite.Interop.dll /output/
	COPY --from=build-interop-stage /src/bin/2013/Release/bin/libSQLite.Interop.so /output/
	COPY --from=build-managed-stage /src/bin/NetStandard21/ReleaseNetStandard21/bin/netstandard2.1/System.Data.SQLite.dll /output/
