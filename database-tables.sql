-- Create the Database
CREATE DATABASE BroadcastOps;
GO

USE BroadcastOps;
GO

/* ============================================================================
   1. CORE INFRASTRUCTURE TABLES
   ============================================================================ */

-- Module 4.1: Identity & Access Management Module (Core User Entity)
CREATE TABLE [User] (
    UserID INT IDENTITY(1,1) PRIMARY KEY,
    Name VARCHAR(255) NOT NULL,
    Role VARCHAR(50) NOT NULL CHECK (Role IN ('SchedulingEditor', 'ContentLibrarian', 'TrafficOperator', 'TransmissionController', 'ComplianceOfficer', 'Admin')),
    Email VARCHAR(255) NOT NULL,
    Phone VARCHAR(50) NOT NULL,
    ChannelID INT NOT NULL, -- Logical relationship to Channel
    Status VARCHAR(20) NOT NULL CHECK (Status IN ('Active', 'Inactive'))
);

-- Module 4.3: Programme Schedule Planning & Publication Module (Core Channel Entity)
CREATE TABLE [Channel] (
    ChannelID INT IDENTITY(1,1) PRIMARY KEY,
    ChannelName VARCHAR(255) NOT NULL,
    ChannelType VARCHAR(50) NOT NULL CHECK (ChannelType IN ('FreeToAir', 'Pay', 'News', 'Sports', 'Entertainment', 'Kids')),
    BroadcastHoursStart TIME NOT NULL,
    BroadcastHoursEnd TIME NOT NULL,
    Status VARCHAR(20) NOT NULL CHECK (Status IN ('Active', 'Inactive'))
);


/* ============================================================================
   2. OPERATIONAL MODULE TABLES (WITH RELATIONAL CONTRAINTS)
   ============================================================================ */

-- Module 4.1: Audit Trails
CREATE TABLE AuditLog (
    AuditID INT IDENTITY(1,1) PRIMARY KEY,
    UserID INT NOT NULL FOREIGN KEY REFERENCES [User](UserID),
    Action VARCHAR(255) NOT NULL,
    EntityType VARCHAR(100) NOT NULL,
    RecordID INT NOT NULL,
    Timestamp DATETIME NOT NULL DEFAULT GETDATE()
);

-- Module 4.2: Content Library & Ingestion Management Module
CREATE TABLE ContentAsset (
    AssetID INT IDENTITY(1,1) PRIMARY KEY,
    Title VARCHAR(255) NOT NULL,
    AssetType VARCHAR(50) NOT NULL CHECK (AssetType IN ('Drama', 'News', 'Sports', 'Documentary', 'Film', 'Animation', 'Commercial', 'Promo')),
    Genre VARCHAR(100) NOT NULL,
    Language VARCHAR(100) NOT NULL,
    Duration TIME NOT NULL,
    ProductionYear INT NOT NULL,
    OriginCountry VARCHAR(100) NOT NULL,
    ContentClassification VARCHAR(10) NOT NULL CHECK (ContentClassification IN ('U', 'UA', 'A', 'S')),
    FilePath VARCHAR(MAX) NOT NULL,
    Status VARCHAR(20) NOT NULL CHECK (Status IN ('Pending', 'Ingested', 'QCApproved', 'Available', 'Archived', 'Withdrawn'))
);

CREATE TABLE RightsRecord (
    RightsID INT IDENTITY(1,1) PRIMARY KEY,
    AssetID INT NOT NULL FOREIGN KEY REFERENCES ContentAsset(AssetID),
    Territory VARCHAR(100) NOT NULL,
    BroadcastMedium VARCHAR(50) NOT NULL CHECK (BroadcastMedium IN ('FreeToAir', 'Cable', 'Satellite', 'OTT')),
    RightsStartDate DATE NOT NULL,
    RightsEndDate DATE NOT NULL,
    MaxTransmissions INT NOT NULL,
    TransmissionsUsed INT NOT NULL,
    Status VARCHAR(20) NOT NULL CHECK (Status IN ('Valid', 'Expiring', 'Expired'))
);

CREATE TABLE IngestJob (
    IngestID INT IDENTITY(1,1) PRIMARY KEY,
    AssetID INT NOT NULL FOREIGN KEY REFERENCES ContentAsset(AssetID),
    SourceFormat VARCHAR(100) NOT NULL,
    IngestedByID INT NOT NULL FOREIGN KEY REFERENCES [User](UserID),
    IngestDate DATETIME NOT NULL,
    QCStatus VARCHAR(20) NOT NULL CHECK (QCStatus IN ('Pending', 'Passed', 'Failed')),
    QCNotes VARCHAR(MAX) NULL,
    Status VARCHAR(20) NOT NULL CHECK (Status IN ('Queued', 'InProgress', 'Completed', 'Failed'))
);

-- Module 4.3: Programme Schedule Planning & Publication Module
CREATE TABLE ProgrammeSlot (
    SlotID INT IDENTITY(1,1) PRIMARY KEY,
    ChannelID INT NOT NULL FOREIGN KEY REFERENCES [Channel](ChannelID),
    BroadcastDate DATE NOT NULL,
    StartTime TIME NOT NULL,
    EndTime TIME NOT NULL,
    AssetID INT NOT NULL FOREIGN KEY REFERENCES ContentAsset(AssetID),
    SlotType VARCHAR(50) NOT NULL CHECK (SlotType IN ('Main', 'Premiere', 'Repeat', 'Filler', 'Live', 'Promo')),
    ScheduledByID INT NOT NULL FOREIGN KEY REFERENCES [User](UserID),
    Status VARCHAR(20) NOT NULL CHECK (Status IN ('Planned', 'Confirmed', 'OnAir', 'Completed', 'Cancelled'))
);

CREATE TABLE ScheduleVersion (
    VersionID INT IDENTITY(1,1) PRIMARY KEY,
    ChannelID INT NOT NULL FOREIGN KEY REFERENCES [Channel](ChannelID),
    BroadcastDate DATE NOT NULL,
    VersionNumber INT NOT NULL,
    PublishedByID INT NOT NULL FOREIGN KEY REFERENCES [User](UserID),
    PublishedDate DATETIME NOT NULL,
    Status VARCHAR(20) NOT NULL CHECK (Status IN ('Draft', 'Published', 'Superseded'))
);

-- Module 4.4: Commercial Traffic & Ad Break Management Module
CREATE TABLE CommercialBreak (
    BreakID INT IDENTITY(1,1) PRIMARY KEY,
    SlotID INT NOT NULL FOREIGN KEY REFERENCES ProgrammeSlot(SlotID),
    ChannelID INT NOT NULL FOREIGN KEY REFERENCES [Channel](ChannelID),
    BroadcastDate DATE NOT NULL,
    BreakStartTime TIME NOT NULL,
    BreakDurationSeconds INT NOT NULL,
    AllocatedSpots INT NOT NULL,
    FilledSpots INT NOT NULL,
    Status VARCHAR(20) NOT NULL CHECK (Status IN ('Open', 'PartiallyFilled', 'FullyBooked', 'Transmitted'))
);

CREATE TABLE AdSpotBooking (
    SpotID INT IDENTITY(1,1) PRIMARY KEY,
    BreakID INT NOT NULL FOREIGN KEY REFERENCES CommercialBreak(BreakID),
    AdvertiserName VARCHAR(255) NOT NULL,
    CampaignRef VARCHAR(100) NOT NULL,
    SpotDurationSeconds INT NOT NULL,
    PositionInBreak INT NOT NULL,
    ContractedRate DECIMAL(18,2) NOT NULL,
    Status VARCHAR(20) NOT NULL CHECK (Status IN ('Booked', 'Confirmed', 'Transmitted', 'Makegooded', 'Cancelled'))
);

-- Module 4.5: Transmission Log & On-Air Monitoring Module
CREATE TABLE TransmissionLog (
    LogID INT IDENTITY(1,1) PRIMARY KEY,
    SlotID INT NOT NULL FOREIGN KEY REFERENCES ProgrammeSlot(SlotID),
    ChannelID INT NOT NULL FOREIGN KEY REFERENCES [Channel](ChannelID),
    BroadcastDate DATE NOT NULL,
    ActualStartTime TIME NOT NULL,
    ActualEndTime TIME NOT NULL,
    AssetTransmitted INT NOT NULL FOREIGN KEY REFERENCES ContentAsset(AssetID),
    VarianceSeconds INT NOT NULL,
    TransmissionStatus VARCHAR(50) NOT NULL CHECK (TransmissionStatus IN ('AsScheduled', 'EarlyStart', 'LateStart', 'Substituted', 'TechnicalFailure', 'Abandoned'))
);

CREATE TABLE TransmissionIncident (
    IncidentID INT IDENTITY(1,1) PRIMARY KEY,
    LogID INT NOT NULL FOREIGN KEY REFERENCES TransmissionLog(LogID),
    IncidentType VARCHAR(50) NOT NULL CHECK (IncidentType IN ('SignalLoss', 'ContentError', 'AudioFault', 'WrongAsset', 'ScheduleBreak')),
    Duration INT NOT NULL, -- Duration in seconds/minutes
    ReportedByID INT NOT NULL FOREIGN KEY REFERENCES [User](UserID),
    RaisedTime DATETIME NOT NULL,
    ResolutionTime DATETIME NULL,
    Status VARCHAR(20) NOT NULL CHECK (Status IN ('Open', 'Resolved', 'Reported'))
);

-- Module 4.6: Content Rights & Compliance Management Module
CREATE TABLE RegulatoryObligation (
    ObligationID INT IDENTITY(1,1) PRIMARY KEY,
    ChannelID INT NOT NULL FOREIGN KEY REFERENCES [Channel](ChannelID),
    ObligationType VARCHAR(100) NOT NULL CHECK (ObligationType IN ('SubtitlingQuota', 'AudioDescriptionQuota', 'OriginContent', 'WatershedCompliance', 'AdvertisingMinutes')),
    MeasurementPeriod VARCHAR(50) NOT NULL,
    TargetValue VARCHAR(50) NOT NULL,
    ActualValue VARCHAR(50) NOT NULL,
    ComplianceStatus VARCHAR(20) NOT NULL CHECK (ComplianceStatus IN ('Compliant', 'AtRisk', 'Breached')),
    ReportingDeadline DATE NOT NULL
);

CREATE TABLE ContentComplianceFlag (
    FlagID INT IDENTITY(1,1) PRIMARY KEY,
    AssetID INT NOT NULL FOREIGN KEY REFERENCES ContentAsset(AssetID),
    SlotID INT NOT NULL FOREIGN KEY REFERENCES ProgrammeSlot(SlotID),
    FlagType VARCHAR(100) NOT NULL CHECK (FlagType IN ('RightsExpired', 'ClassificationMismatch', 'WatershedViolation', 'AdvertisingLimitBreach')),
    FlaggedDate DATETIME NOT NULL,
    ReviewedByID INT NOT NULL FOREIGN KEY REFERENCES [User](UserID),
    Status VARCHAR(20) NOT NULL CHECK (Status IN ('Open', 'Cleared', 'Reported'))
);


/* ============================================================================
   3. CROSS-FUNCTIONAL INFRASTRUCTURE TABLES
   ============================================================================ */

-- Module 4.7: Broadcast Analytics & Reporting Module
CREATE TABLE BroadcastReport (
    ReportID INT IDENTITY(1,1) PRIMARY KEY,
    Scope VARCHAR(100) NOT NULL, -- (Channel/Period/ContentType)
    Metrics VARCHAR(MAX) NOT NULL, -- Holds summary metadata descriptions perfectly matching doc
    GeneratedDate DATETIME NOT NULL DEFAULT GETDATE()
);

-- Module 4.8: Notifications & Alerts Module
CREATE TABLE Notification (
    NotificationID INT IDENTITY(1,1) PRIMARY KEY,
    UserID INT NOT NULL FOREIGN KEY REFERENCES [User](UserID),
    Message VARCHAR(MAX) NOT NULL,
    Category VARCHAR(50) NOT NULL CHECK (Category IN ('Schedule', 'Rights', 'Transmission', 'AdBreak', 'Compliance', 'Incident')),
    Status VARCHAR(20) NOT NULL CHECK (Status IN ('Unread', 'Read', 'Dismissed')),
    CreatedDate DATETIME NOT NULL DEFAULT GETDATE()
);
GO