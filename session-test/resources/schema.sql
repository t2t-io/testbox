
-- User
--
--
CREATE TABLE Users (
    id              INT         UNSIGNED    NOT NULL AUTO_INCREMENT PRIMARY KEY COMMENT 'the major primary key, auto-incremental',
    email           VARCHAR(128)            NOT NULL,
    name            VARCHAR(32)             NOT NULL,
    pswdhash        CHAR(64)                NOT NULL COMMENT 'Using SHA256 to calculate the hash/digest of password',
    activation      CHAR(32)                NOT NULL COMMENT 'Activation token for email registration',
    agent           CHAR(32)                NOT NULL COMMENT 'Device agent token, for agents installed on any device to connect to Wstty Server',
    api             CHAR(32)                NOT NULL COMMENT 'User api token, for user/developer to access REST APIs',
    activated       BIT(1)                  NOT NULL DEFAULT 0 COMMENT 'mark to be activated',
    deleted         BIT(1)                  NOT NULL DEFAULT 0 COMMENT 'mark to be deleted',
    deletion_cause  VARCHAR(256)            NULL,
    documentation   JSON 					NOT NULL,
    updated_at      TIMESTAMP               NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'when to create',
    updated_by      VARCHAR(32)             NOT NULL COMMENT 'who creates it',
    updated_from    VARCHAR(32)             NOT NULL COMMENT 'which ip address to request creation'
);
