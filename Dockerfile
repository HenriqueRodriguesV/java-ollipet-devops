# Build em duas etapas: a primeira compila com o Maven, a segunda leva apenas o
# jar. A imagem final fica sem o Maven nem o codigo-fonte.
#
# O Java 21 e fixado aqui porque o projeto usa recursos dessa versao, e o padrao
# das plataformas costuma ser mais antigo.

FROM maven:3.9-eclipse-temurin-21 AS build
WORKDIR /app

# As dependencias mudam menos que o codigo: baixa-las antes aproveita o cache
# do Docker e encurta os deploys seguintes.
COPY pom.xml .
RUN mvn -B dependency:go-offline

COPY src ./src
RUN mvn -B clean package -DskipTests

FROM eclipse-temurin:21-jre
WORKDIR /app

# Usuario e grupo dedicados, sem privilegios administrativos: o container da
# aplicacao nao pode rodar como root (exigencia da entrega ACR/ACI).
RUN groupadd --system ollipet && useradd --system --gid ollipet --no-create-home ollipet

COPY --from=build /app/target/*.jar app.jar
RUN chown ollipet:ollipet app.jar

USER ollipet

# A porta real vem da variavel PORT em tempo de execucao; este EXPOSE e apenas
# documentacao para quem le a imagem.
EXPOSE 8080

ENTRYPOINT ["java", "-jar", "app.jar"]
