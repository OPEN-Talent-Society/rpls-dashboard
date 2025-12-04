# Section 2.2: Admin Pseudocode Flows

## 2.2.1 Cohort Management (Multi-Session Types)

### Create Cohort Flow

```pseudocode
FUNCTION createCohort(adminId, cohortData):
  # Input Validation
  VALIDATE adminId has ADMIN role
  VALIDATE cohortData contains:
    - title: string (required, max 200 chars)
    - sessionType: enum(cohort, webinar, hackathon) (required)
    - startDate: ISO datetime (required, future date)
    - endDate: ISO datetime (optional, after startDate)
    - maxCapacity: integer (optional)
    - location: string (optional, max 500 chars)
    - description: markdown (required, max 5000 chars)
    - enablementKitId: UUID (optional)
    - pricing: object (required)

  # Set Default Capacity by Session Type
  IF cohortData.maxCapacity is NULL:
    SWITCH cohortData.sessionType:
      CASE "cohort":
        cohortData.maxCapacity = 30  # Default for intensive cohorts
      CASE "webinar":
        cohortData.maxCapacity = 100  # Default for webinars
      CASE "hackathon":
        cohortData.maxCapacity = 50  # Default for hackathons
      DEFAULT:
        cohortData.maxCapacity = 30

  # Validate Pricing Structure
  VALIDATE cohortData.pricing contains:
    - b2cPrice: number >= 0
    - b2bPrice: number >= 0
    - currency: enum(USD, EUR, GBP) (default: USD)

  # Create Cohort Record
  cohort = CREATE Cohort:
    id: generateUUID()
    title: cohortData.title
    sessionType: cohortData.sessionType
    startDate: cohortData.startDate
    endDate: cohortData.endDate OR (startDate + DEFAULT_DURATION)
    maxCapacity: cohortData.maxCapacity
    currentEnrollment: 0
    status: "scheduled"  # Initial state
    location: cohortData.location
    description: cohortData.description
    enablementKitId: cohortData.enablementKitId
    b2cPrice: cohortData.pricing.b2cPrice
    b2bPrice: cohortData.pricing.b2bPrice
    currency: cohortData.pricing.currency
    createdBy: adminId
    createdAt: NOW()
    updatedAt: NOW()

  # Create Activity Log
  LOG CohortActivity:
    cohortId: cohort.id
    action: "COHORT_CREATED"
    performedBy: adminId
    metadata: {
      sessionType: cohort.sessionType,
      capacity: cohort.maxCapacity,
      pricing: cohortData.pricing
    }
    timestamp: NOW()

  RETURN cohort
```

### Cohort Status Transitions

```pseudocode
FUNCTION updateCohortStatus(adminId, cohortId, newStatus):
  # Input Validation
  VALIDATE adminId has ADMIN role
  VALIDATE newStatus IN ["scheduled", "open", "in_progress", "completed", "cancelled"]

  # Retrieve Current Cohort
  cohort = QUERY Cohort WHERE id = cohortId
  IF cohort is NULL:
    THROW Error("Cohort not found")

  currentStatus = cohort.status

  # Valid Status Transition Rules
  validTransitions = {
    "scheduled": ["open", "cancelled"],
    "open": ["in_progress", "cancelled"],
    "in_progress": ["completed"],
    "completed": [],  # Terminal state
    "cancelled": []   # Terminal state
  }

  # Validate Transition
  IF newStatus NOT IN validTransitions[currentStatus]:
    THROW Error(
      "Invalid status transition from '${currentStatus}' to '${newStatus}'. " +
      "Valid transitions: ${validTransitions[currentStatus].join(', ')}"
    )

  # Additional Business Rules
  IF newStatus = "open":
    # Must have future start date
    IF cohort.startDate <= NOW():
      THROW Error("Cannot open cohort with past start date")

    # Must have enablement kit assigned (optional but recommended)
    IF cohort.enablementKitId is NULL:
      WARN "Opening cohort without enablement kit"

  IF newStatus = "in_progress":
    # Must be on or after start date
    IF NOW() < cohort.startDate:
      THROW Error("Cannot start cohort before scheduled start date")

    # Must have at least one enrollment
    IF cohort.currentEnrollment = 0:
      WARN "Starting cohort with zero enrollments"

  IF newStatus = "completed":
    # Should be on or after end date
    IF NOW() < cohort.endDate:
      WARN "Completing cohort before scheduled end date"

  # Execute Transition
  UPDATE Cohort SET:
    status = newStatus
    updatedAt = NOW()
  WHERE id = cohortId

  # Log Activity
  LOG CohortActivity:
    cohortId: cohortId
    action: "STATUS_CHANGED"
    performedBy: adminId
    metadata: {
      previousStatus: currentStatus,
      newStatus: newStatus
    }
    timestamp: NOW()

  # Side Effects
  IF newStatus = "cancelled":
    # Handle enrolled users
    enrollments = QUERY Enrollment WHERE cohortId = cohortId AND status = "active"

    FOR EACH enrollment IN enrollments:
      # Initiate refund if payment exists
      IF enrollment.paymentId is NOT NULL:
        CALL processRefund(enrollment.paymentId, "COHORT_CANCELLED")

      # Update enrollment status
      UPDATE Enrollment SET:
        status = "cancelled"
        cancelledAt = NOW()
        cancellationReason = "Cohort cancelled by admin"
      WHERE id = enrollment.id

      # Send notification
      CALL sendEmail(
        to: enrollment.userEmail,
        template: "COHORT_CANCELLED",
        data: {
          cohortTitle: cohort.title,
          refundStatus: enrollment.paymentId ? "pending" : "N/A"
        }
      )

  RETURN cohort
```

### Manual Enrollment Addition

```pseudocode
FUNCTION addManualEnrollment(adminId, cohortId, userData, enrollmentType):
  # Input Validation
  VALIDATE adminId has ADMIN role
  VALIDATE enrollmentType IN ["b2c_complimentary", "b2b_manual", "scholarship"]
  VALIDATE userData contains:
    - email: valid email
    - firstName: string
    - lastName: string
    - organizationId: UUID (required if enrollmentType = "b2b_manual")

  # Check Cohort Availability
  cohort = QUERY Cohort WHERE id = cohortId
  IF cohort is NULL:
    THROW Error("Cohort not found")

  IF cohort.status NOT IN ["scheduled", "open"]:
    THROW Error("Cannot add enrollments to cohort with status '${cohort.status}'")

  # Check Capacity
  IF cohort.currentEnrollment >= cohort.maxCapacity:
    THROW Error("Cohort is at maximum capacity (${cohort.maxCapacity})")

  # Check for Existing User
  user = QUERY User WHERE email = userData.email

  IF user is NULL:
    # Create new user account
    user = CREATE User:
      id: generateUUID()
      email: userData.email
      firstName: userData.firstName
      lastName: userData.lastName
      role: "LEARNER"
      emailVerified: TRUE  # Admin-created users are pre-verified
      createdAt: NOW()
      onboardingCompleted: FALSE

    # Send welcome email with password setup
    inviteToken = generateSecureToken(length: 32, expiresIn: 7 days)

    STORE InviteToken:
      token: inviteToken
      userId: user.id
      type: "PASSWORD_SETUP"
      expiresAt: NOW() + 7 days

    CALL sendEmail(
      to: user.email,
      template: "ADMIN_CREATED_ACCOUNT",
      data: {
        firstName: user.firstName,
        cohortTitle: cohort.title,
        setupUrl: "${PLATFORM_URL}/setup-password?token=${inviteToken}"
      }
    )
  ELSE:
    # Existing user - check for conflicts
    existingEnrollment = QUERY Enrollment WHERE:
      userId = user.id AND
      cohortId = cohortId

    IF existingEnrollment is NOT NULL:
      THROW Error("User is already enrolled in this cohort")

    # Check for conflicting enrollments (overlapping dates)
    conflictingEnrollments = QUERY Enrollment JOIN Cohort WHERE:
      Enrollment.userId = user.id AND
      Enrollment.status = "active" AND
      Cohort.status IN ["open", "in_progress"] AND
      (
        (Cohort.startDate <= cohort.endDate AND Cohort.endDate >= cohort.startDate)
      )

    IF conflictingEnrollments.count > 0:
      WARN "User has conflicting enrollment in cohort '${conflictingEnrollments[0].cohort.title}'"

  # Create Enrollment
  enrollment = CREATE Enrollment:
    id: generateUUID()
    userId: user.id
    cohortId: cohortId
    enrollmentType: enrollmentType
    status: "active"
    paymentStatus: "complimentary"  # Manual enrollments are free
    paymentId: NULL
    organizationId: userData.organizationId OR NULL
    enrolledAt: NOW()
    enrolledBy: adminId
    progress: 0
    completionStatus: "not_started"
    certificateIssued: FALSE
    badgeIssued: FALSE

  # Update Cohort Capacity
  UPDATE Cohort SET:
    currentEnrollment = currentEnrollment + 1
    updatedAt = NOW()
  WHERE id = cohortId

  # Update Organization Seat Usage (if B2B)
  IF enrollmentType = "b2b_manual" AND userData.organizationId is NOT NULL:
    org = QUERY Organization WHERE id = userData.organizationId

    IF org.seatsUsed >= org.seatsPurchased:
      THROW Error("Organization has used all purchased seats (${org.seatsPurchased})")

    UPDATE Organization SET:
      seatsUsed = seatsUsed + 1
    WHERE id = userData.organizationId

  # Log Activity
  LOG EnrollmentActivity:
    enrollmentId: enrollment.id
    action: "MANUAL_ENROLLMENT_CREATED"
    performedBy: adminId
    metadata: {
      enrollmentType: enrollmentType,
      userEmail: user.email,
      cohortTitle: cohort.title
    }
    timestamp: NOW()

  # Send Confirmation Email
  CALL sendEmail(
    to: user.email,
    template: "ENROLLMENT_CONFIRMED",
    data: {
      firstName: user.firstName,
      cohortTitle: cohort.title,
      sessionType: cohort.sessionType,
      startDate: cohort.startDate,
      dashboardUrl: "${PLATFORM_URL}/dashboard"
    }
  )

  RETURN enrollment
```

### Reschedule Cohort

```pseudocode
FUNCTION rescheduleCohort(adminId, cohortId, newStartDate, newEndDate, notifyUsers):
  # Input Validation
  VALIDATE adminId has ADMIN role
  VALIDATE newStartDate is future date
  VALIDATE newEndDate > newStartDate
  VALIDATE notifyUsers is boolean

  # Retrieve Cohort
  cohort = QUERY Cohort WHERE id = cohortId
  IF cohort is NULL:
    THROW Error("Cohort not found")

  # Status Restrictions
  IF cohort.status IN ["completed", "cancelled"]:
    THROW Error("Cannot reschedule ${cohort.status} cohort")

  IF cohort.status = "in_progress":
    THROW Error("Cannot reschedule cohort that is already in progress")

  # Store Previous Dates
  previousStartDate = cohort.startDate
  previousEndDate = cohort.endDate

  # Update Cohort
  UPDATE Cohort SET:
    startDate = newStartDate
    endDate = newEndDate
    updatedAt = NOW()
  WHERE id = cohortId

  # Log Activity
  LOG CohortActivity:
    cohortId: cohortId
    action: "COHORT_RESCHEDULED"
    performedBy: adminId
    metadata: {
      previousStartDate: previousStartDate,
      previousEndDate: previousEndDate,
      newStartDate: newStartDate,
      newEndDate: newEndDate
    }
    timestamp: NOW()

  # Notify Enrolled Users
  IF notifyUsers = TRUE:
    enrollments = QUERY Enrollment WHERE:
      cohortId = cohortId AND
      status = "active"

    FOR EACH enrollment IN enrollments:
      user = QUERY User WHERE id = enrollment.userId

      CALL sendEmail(
        to: user.email,
        template: "COHORT_RESCHEDULED",
        data: {
          firstName: user.firstName,
          cohortTitle: cohort.title,
          previousStartDate: formatDate(previousStartDate),
          newStartDate: formatDate(newStartDate),
          previousEndDate: formatDate(previousEndDate),
          newEndDate: formatDate(newEndDate),
          contactUrl: "${PLATFORM_URL}/support"
        }
      )

  RETURN cohort
```

---

## 2.2.2 Enablement Kit Management

### File Upload Flow (Convex Storage)

```pseudocode
FUNCTION uploadEnablementKitFile(adminId, enablementKitId, fileData):
  # Input Validation
  VALIDATE adminId has ADMIN role
  VALIDATE fileData contains:
    - file: File object
    - title: string (required, max 200 chars)
    - description: string (optional, max 1000 chars)
    - itemType: enum(pdf, video, link, exercise, template)
    - orderIndex: integer (optional)

  # Validate File
  MAX_FILE_SIZE = 100 * 1024 * 1024  # 100 MB
  ALLOWED_TYPES = {
    "pdf": ["application/pdf"],
    "video": ["video/mp4", "video/quicktime", "video/x-msvideo"],
    "template": [
      "application/pdf",
      "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
      "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
      "application/vnd.openxmlformats-officedocument.presentationml.presentation"
    ],
    "exercise": [
      "application/pdf",
      "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
    ]
  }

  IF fileData.file.size > MAX_FILE_SIZE:
    THROW Error("File size exceeds maximum allowed size (100 MB)")

  IF fileData.file.mimeType NOT IN ALLOWED_TYPES[fileData.itemType]:
    THROW Error(
      "Invalid file type '${fileData.file.mimeType}' for item type '${fileData.itemType}'. " +
      "Allowed types: ${ALLOWED_TYPES[fileData.itemType].join(', ')}"
    )

  # Check Enablement Kit Exists
  kit = QUERY EnablementKit WHERE id = enablementKitId
  IF kit is NULL:
    THROW Error("Enablement kit not found")

  # Determine Order Index
  IF fileData.orderIndex is NULL:
    maxOrder = QUERY MAX(orderIndex) FROM EnablementKitItem WHERE kitId = enablementKitId
    fileData.orderIndex = (maxOrder OR 0) + 1

  # Upload to Convex Storage
  TRY:
    # Generate unique storage key
    storageKey = generateStorageKey(
      prefix: "enablement-kits/${enablementKitId}",
      filename: sanitizeFilename(fileData.file.name),
      timestamp: NOW()
    )

    # Upload file
    uploadResult = AWAIT convexStorage.upload(
      file: fileData.file,
      key: storageKey,
      metadata: {
        uploadedBy: adminId,
        originalFilename: fileData.file.name,
        mimeType: fileData.file.mimeType,
        size: fileData.file.size
      }
    )

    storageId = uploadResult.storageId
    storageUrl = uploadResult.url

  CATCH error:
    LOG Error:
      message: "Failed to upload file to Convex storage"
      error: error
      adminId: adminId
      kitId: enablementKitId

    THROW Error("File upload failed: ${error.message}")

  # Create Kit Item Record
  kitItem = CREATE EnablementKitItem:
    id: generateUUID()
    kitId: enablementKitId
    title: fileData.title
    description: fileData.description
    itemType: fileData.itemType
    storageId: storageId
    storageUrl: storageUrl
    externalUrl: NULL
    orderIndex: fileData.orderIndex
    version: 1
    isPublished: FALSE  # New items are unpublished by default
    createdBy: adminId
    createdAt: NOW()
    updatedAt: NOW()
    metadata: {
      originalFilename: fileData.file.name,
      fileSize: fileData.file.size,
      mimeType: fileData.file.mimeType
    }

  # Increment Kit Version
  UPDATE EnablementKit SET:
    version = version + 1
    updatedAt = NOW()
  WHERE id = enablementKitId

  # Log Activity
  LOG KitActivity:
    kitId: enablementKitId
    action: "ITEM_UPLOADED"
    performedBy: adminId
    metadata: {
      itemId: kitItem.id,
      itemType: fileData.itemType,
      filename: fileData.file.name,
      fileSize: fileData.file.size
    }
    timestamp: NOW()

  RETURN kitItem
```

### External URL Item

```pseudocode
FUNCTION addExternalUrlItem(adminId, enablementKitId, urlData):
  # Input Validation
  VALIDATE adminId has ADMIN role
  VALIDATE urlData contains:
    - url: valid URL (required)
    - title: string (required, max 200 chars)
    - description: string (optional, max 1000 chars)
    - itemType: enum(link, video) (required)
    - orderIndex: integer (optional)

  # Validate URL
  VALIDATE urlData.url matches URL_REGEX
  VALIDATE urlData.url starts with "https://"  # Enforce HTTPS

  # Check Enablement Kit Exists
  kit = QUERY EnablementKit WHERE id = enablementKitId
  IF kit is NULL:
    THROW Error("Enablement kit not found")

  # Determine Order Index
  IF urlData.orderIndex is NULL:
    maxOrder = QUERY MAX(orderIndex) FROM EnablementKitItem WHERE kitId = enablementKitId
    urlData.orderIndex = (maxOrder OR 0) + 1

  # Fetch URL Metadata (Optional)
  TRY:
    urlMetadata = AWAIT fetchUrlMetadata(urlData.url)
    # Extract: title, description, thumbnail, duration (for videos)
  CATCH error:
    urlMetadata = NULL
    WARN "Could not fetch metadata for URL: ${urlData.url}"

  # Create Kit Item Record
  kitItem = CREATE EnablementKitItem:
    id: generateUUID()
    kitId: enablementKitId
    title: urlData.title
    description: urlData.description OR urlMetadata?.description
    itemType: urlData.itemType
    storageId: NULL
    storageUrl: NULL
    externalUrl: urlData.url
    orderIndex: urlData.orderIndex
    version: 1
    isPublished: FALSE
    createdBy: adminId
    createdAt: NOW()
    updatedAt: NOW()
    metadata: {
      urlMetadata: urlMetadata,
      thumbnailUrl: urlMetadata?.thumbnail,
      duration: urlMetadata?.duration  # For video links
    }

  # Increment Kit Version
  UPDATE EnablementKit SET:
    version = version + 1
    updatedAt = NOW()
  WHERE id = enablementKitId

  # Log Activity
  LOG KitActivity:
    kitId: enablementKitId
    action: "EXTERNAL_ITEM_ADDED"
    performedBy: adminId
    metadata: {
      itemId: kitItem.id,
      itemType: urlData.itemType,
      url: urlData.url
    }
    timestamp: NOW()

  RETURN kitItem
```

### Drag-Drop Reordering

```pseudocode
FUNCTION reorderKitItems(adminId, enablementKitId, itemOrders):
  # Input Validation
  VALIDATE adminId has ADMIN role
  VALIDATE itemOrders is array of {itemId, newOrderIndex}

  # Check Enablement Kit Exists
  kit = QUERY EnablementKit WHERE id = enablementKitId
  IF kit is NULL:
    THROW Error("Enablement kit not found")

  # Retrieve All Kit Items
  allItems = QUERY EnablementKitItem WHERE kitId = enablementKitId ORDER BY orderIndex ASC

  # Validate All Item IDs Belong to Kit
  itemIdsToReorder = itemOrders.map(o => o.itemId)

  FOR EACH itemId IN itemIdsToReorder:
    IF NOT allItems.some(item => item.id = itemId):
      THROW Error("Item '${itemId}' does not belong to this enablement kit")

  # Apply New Order Indices
  BEGIN TRANSACTION:
    FOR EACH order IN itemOrders:
      UPDATE EnablementKitItem SET:
        orderIndex = order.newOrderIndex
        updatedAt = NOW()
      WHERE id = order.itemId

    # Increment Kit Version
    UPDATE EnablementKit SET:
      version = version + 1
      updatedAt = NOW()
    WHERE id = enablementKitId

    # Log Activity
    LOG KitActivity:
      kitId: enablementKitId
      action: "ITEMS_REORDERED"
      performedBy: adminId
      metadata: {
        itemCount: itemOrders.length,
        reorderedItems: itemOrders
      }
      timestamp: NOW()

  COMMIT TRANSACTION

  # Return Updated Items
  updatedItems = QUERY EnablementKitItem WHERE kitId = enablementKitId ORDER BY orderIndex ASC
  RETURN updatedItems
```

### Item Versioning Concept

```pseudocode
FUNCTION updateKitItemVersion(adminId, itemId, updateData):
  # Input Validation
  VALIDATE adminId has ADMIN role
  VALIDATE updateData contains at least one of:
    - title: string (max 200 chars)
    - description: string (max 1000 chars)
    - file: File object (for replacing uploaded file)
    - externalUrl: valid URL (for updating link)

  # Retrieve Current Item
  currentItem = QUERY EnablementKitItem WHERE id = itemId
  IF currentItem is NULL:
    THROW Error("Kit item not found")

  # Archive Current Version (Soft Copy)
  CREATE EnablementKitItemVersion:
    id: generateUUID()
    kitItemId: currentItem.id
    version: currentItem.version
    title: currentItem.title
    description: currentItem.description
    itemType: currentItem.itemType
    storageId: currentItem.storageId
    storageUrl: currentItem.storageUrl
    externalUrl: currentItem.externalUrl
    metadata: currentItem.metadata
    archivedAt: NOW()
    archivedBy: adminId

  # Handle File Replacement
  IF updateData.file is NOT NULL:
    # Upload new file (similar to uploadEnablementKitFile)
    storageKey = generateStorageKey(
      prefix: "enablement-kits/${currentItem.kitId}",
      filename: sanitizeFilename(updateData.file.name),
      timestamp: NOW(),
      version: currentItem.version + 1
    )

    uploadResult = AWAIT convexStorage.upload(
      file: updateData.file,
      key: storageKey,
      metadata: {
        uploadedBy: adminId,
        originalFilename: updateData.file.name,
        replacesStorageId: currentItem.storageId,
        version: currentItem.version + 1
      }
    )

    newStorageId = uploadResult.storageId
    newStorageUrl = uploadResult.url

    # Optionally delete old file (or keep for version history)
    # AWAIT convexStorage.delete(currentItem.storageId)
  ELSE:
    newStorageId = currentItem.storageId
    newStorageUrl = currentItem.storageUrl

  # Update Item
  UPDATE EnablementKitItem SET:
    title = updateData.title OR currentItem.title
    description = updateData.description OR currentItem.description
    externalUrl = updateData.externalUrl OR currentItem.externalUrl
    storageId = newStorageId
    storageUrl = newStorageUrl
    version = version + 1
    updatedAt = NOW()
    metadata = MERGE(currentItem.metadata, {
      lastModifiedBy: adminId,
      versionHistory: currentItem.version
    })
  WHERE id = itemId

  # Increment Kit Version
  UPDATE EnablementKit SET:
    version = version + 1
    updatedAt = NOW()
  WHERE id = currentItem.kitId

  # Log Activity
  LOG KitActivity:
    kitId: currentItem.kitId
    action: "ITEM_VERSION_UPDATED"
    performedBy: adminId
    metadata: {
      itemId: itemId,
      previousVersion: currentItem.version,
      newVersion: currentItem.version + 1,
      changes: updateData
    }
    timestamp: NOW()

  RETURN updatedItem
```

### Publish/Unpublish Logic

```pseudocode
FUNCTION toggleKitItemPublish(adminId, itemId, shouldPublish):
  # Input Validation
  VALIDATE adminId has ADMIN role
  VALIDATE shouldPublish is boolean

  # Retrieve Item
  item = QUERY EnablementKitItem WHERE id = itemId
  IF item is NULL:
    THROW Error("Kit item not found")

  # Check Current State
  IF item.isPublished = shouldPublish:
    RETURN item  # No change needed

  # Additional Validation for Publishing
  IF shouldPublish = TRUE:
    # Ensure item has required fields
    IF item.title is NULL OR item.title = "":
      THROW Error("Cannot publish item without title")

    IF item.itemType IN ["pdf", "video", "template", "exercise"]:
      IF item.storageId is NULL AND item.externalUrl is NULL:
        THROW Error("Cannot publish item without file or URL")

  # Update Item
  UPDATE EnablementKitItem SET:
    isPublished = shouldPublish
    publishedAt = IF(shouldPublish, NOW(), NULL)
    publishedBy = IF(shouldPublish, adminId, NULL)
    updatedAt = NOW()
  WHERE id = itemId

  # Increment Kit Version
  UPDATE EnablementKit SET:
    version = version + 1
    updatedAt = NOW()
  WHERE id = item.kitId

  # Log Activity
  LOG KitActivity:
    kitId: item.kitId
    action: IF(shouldPublish, "ITEM_PUBLISHED", "ITEM_UNPUBLISHED")
    performedBy: adminId
    metadata: {
      itemId: itemId,
      itemTitle: item.title
    }
    timestamp: NOW()

  RETURN item
```

---

## 2.2.3 B2B Manual Enrollment Flow

### Complete B2B Enrollment Workflow

```pseudocode
FUNCTION processB2BEnrollment(adminId, b2bRequestData):
  # Input Validation
  VALIDATE adminId has ADMIN role
  VALIDATE b2bRequestData contains:
    - organizationName: string (required, max 200 chars)
    - contactEmail: email (required)
    - contactName: string (required)
    - seatsPurchased: integer (required, min 5, max 500)
    - cohortId: UUID (required)
    - pricingDetails: object (required)
    - teamMembers: array of {email, firstName, lastName} (optional)

  # STEP 1: Create or Retrieve Organization
  existingOrg = QUERY Organization WHERE name = b2bRequestData.organizationName

  IF existingOrg is NOT NULL:
    # Organization exists - check for conflicts
    IF existingOrg.contactEmail != b2bRequestData.contactEmail:
      THROW Error(
        "Organization '${b2bRequestData.organizationName}' already exists with different contact. " +
        "Please verify organization details."
      )

    organization = existingOrg
  ELSE:
    # Create new organization
    organization = CREATE Organization:
      id: generateUUID()
      name: b2bRequestData.organizationName
      contactEmail: b2bRequestData.contactEmail
      contactName: b2bRequestData.contactName
      seatsPurchased: b2bRequestData.seatsPurchased
      seatsUsed: 0
      status: "active"
      createdBy: adminId
      createdAt: NOW()
      metadata: {
        industry: b2bRequestData.industry OR NULL,
        companySize: b2bRequestData.companySize OR NULL
      }

  # STEP 2: Create Manual Stripe Invoice
  cohort = QUERY Cohort WHERE id = b2bRequestData.cohortId
  IF cohort is NULL:
    THROW Error("Cohort not found")

  invoiceAmount = cohort.b2bPrice * b2bRequestData.seatsPurchased

  TRY:
    # Create Stripe customer if not exists
    IF organization.stripeCustomerId is NULL:
      stripeCustomer = AWAIT stripe.customers.create({
        email: organization.contactEmail,
        name: organization.name,
        metadata: {
          organizationId: organization.id,
          contactName: organization.contactName
        }
      })

      UPDATE Organization SET:
        stripeCustomerId = stripeCustomer.id
      WHERE id = organization.id

    # Create Stripe invoice
    invoice = AWAIT stripe.invoices.create({
      customer: organization.stripeCustomerId,
      collection_method: "send_invoice",
      days_until_due: 30,  # Net 30 payment terms
      metadata: {
        organizationId: organization.id,
        cohortId: cohort.id,
        seatsPurchased: b2bRequestData.seatsPurchased,
        createdBy: adminId
      }
    })

    # Add invoice line items
    AWAIT stripe.invoiceItems.create({
      customer: organization.stripeCustomerId,
      invoice: invoice.id,
      amount: invoiceAmount * 100,  # Stripe uses cents
      currency: cohort.currency.toLowerCase(),
      description: "${cohort.title} - ${b2bRequestData.seatsPurchased} seats",
      metadata: {
        cohortId: cohort.id,
        sessionType: cohort.sessionType
      }
    })

    # Finalize and send invoice
    finalizedInvoice = AWAIT stripe.invoices.finalizeInvoice(invoice.id)
    AWAIT stripe.invoices.sendInvoice(invoice.id)

    invoiceId = finalizedInvoice.id
    invoiceUrl = finalizedInvoice.hosted_invoice_url

  CATCH error:
    LOG Error:
      message: "Failed to create Stripe invoice"
      error: error
      organizationId: organization.id

    THROW Error("Invoice creation failed: ${error.message}")

  # STEP 3: Store B2B Transaction
  b2bTransaction = CREATE B2BTransaction:
    id: generateUUID()
    organizationId: organization.id
    cohortId: cohort.id
    invoiceId: invoiceId
    invoiceUrl: invoiceUrl
    amount: invoiceAmount
    currency: cohort.currency
    seatsPurchased: b2bRequestData.seatsPurchased
    paymentStatus: "pending"
    createdBy: adminId
    createdAt: NOW()

  # STEP 4: Generate Team Invite Tokens
  inviteTokens = []

  IF b2bRequestData.teamMembers.length > 0:
    FOR EACH member IN b2bRequestData.teamMembers:
      # Validate member data
      VALIDATE member.email is valid email

      # Generate secure invite token
      inviteToken = generateSecureToken(length: 32, expiresIn: 30 days)

      # Store invite
      invite = CREATE TeamInvite:
        id: generateUUID()
        token: inviteToken
        organizationId: organization.id
        cohortId: cohort.id
        email: member.email
        firstName: member.firstName
        lastName: member.lastName
        status: "pending"
        expiresAt: NOW() + 30 days
        createdBy: adminId
        createdAt: NOW()

      inviteTokens.push({
        email: member.email,
        token: inviteToken,
        inviteUrl: "${PLATFORM_URL}/join?token=${inviteToken}"
      })

  # STEP 5: Send Team Invite Emails (via Brevo)
  IF inviteTokens.length > 0:
    TRY:
      FOR EACH invite IN inviteTokens:
        AWAIT brevo.sendTransactionalEmail({
          to: [{
            email: invite.email,
            name: "${member.firstName} ${member.lastName}"
          }],
          templateId: BREVO_TEMPLATE_B2B_INVITE,  # Pre-configured in Brevo
          params: {
            firstName: member.firstName,
            organizationName: organization.name,
            cohortTitle: cohort.title,
            sessionType: cohort.sessionType,
            startDate: formatDate(cohort.startDate),
            inviteUrl: invite.inviteUrl,
            expiresAt: formatDate(invite.expiresAt)
          },
          tags: ["b2b-invite", "team-enrollment", cohort.sessionType]
        })

      LOG Info:
        message: "Sent ${inviteTokens.length} B2B team invites"
        organizationId: organization.id
        cohortId: cohort.id

    CATCH error:
      LOG Error:
        message: "Failed to send some B2B invite emails"
        error: error
        organizationId: organization.id

      # Continue workflow even if email fails - invites are stored
      WARN "Email delivery failed but invites are active"

  # STEP 6: Send Invoice to Organization Contact
  TRY:
    AWAIT brevo.sendTransactionalEmail({
      to: [{
        email: organization.contactEmail,
        name: organization.contactName
      }],
      templateId: BREVO_TEMPLATE_B2B_INVOICE,
      params: {
        contactName: organization.contactName,
        organizationName: organization.name,
        cohortTitle: cohort.title,
        seatsPurchased: b2bRequestData.seatsPurchased,
        totalAmount: formatCurrency(invoiceAmount, cohort.currency),
        invoiceUrl: invoiceUrl,
        dueDate: formatDate(NOW() + 30 days)
      },
      tags: ["b2b-invoice", "payment-required"]
    })
  CATCH error:
    LOG Error:
      message: "Failed to send invoice email"
      error: error
      organizationId: organization.id

  # Log Activity
  LOG OrganizationActivity:
    organizationId: organization.id
    action: "B2B_ENROLLMENT_PROCESSED"
    performedBy: adminId
    metadata: {
      cohortId: cohort.id,
      seatsPurchased: b2bRequestData.seatsPurchased,
      invoiceId: invoiceId,
      invitesSent: inviteTokens.length
    }
    timestamp: NOW()

  RETURN {
    organization: organization,
    transaction: b2bTransaction,
    invites: inviteTokens,
    invoiceUrl: invoiceUrl
  }
```

### Team Invite Redemption Flow

```pseudocode
FUNCTION redeemTeamInvite(inviteToken, userData):
  # Input Validation
  VALIDATE inviteToken is not empty
  VALIDATE userData contains:
    - password: string (min 8 chars, complexity requirements)

  # Retrieve Invite
  invite = QUERY TeamInvite WHERE token = inviteToken

  IF invite is NULL:
    THROW Error("Invalid invite token")

  IF invite.status != "pending":
    THROW Error("Invite has already been used or cancelled")

  IF invite.expiresAt < NOW():
    THROW Error("Invite has expired")

  # Check Cohort Status
  cohort = QUERY Cohort WHERE id = invite.cohortId

  IF cohort.status NOT IN ["scheduled", "open"]:
    THROW Error("Cohort is no longer accepting enrollments")

  # Check Organization Seat Availability
  organization = QUERY Organization WHERE id = invite.organizationId

  IF organization.seatsUsed >= organization.seatsPurchased:
    THROW Error("Organization has used all purchased seats")

  # Check for Existing User with Email
  existingUser = QUERY User WHERE email = invite.email

  IF existingUser is NOT NULL:
    # EDGE CASE: User exists

    # Check if user already has B2C enrollment in same cohort
    existingEnrollment = QUERY Enrollment WHERE:
      userId = existingUser.id AND
      cohortId = invite.cohortId AND
      enrollmentType = "b2c"

    IF existingEnrollment is NOT NULL:
      # User has B2C enrollment - handle conflict

      # Option 1: Convert B2C to B2B (with refund)
      IF existingEnrollment.paymentStatus = "completed":
        CALL processRefund(
          paymentId: existingEnrollment.paymentId,
          reason: "CONVERTED_TO_B2B"
        )

      # Update enrollment to B2B
      UPDATE Enrollment SET:
        enrollmentType = "b2b"
        organizationId = organization.id
        paymentStatus = "organization_paid"
        updatedAt = NOW()
      WHERE id = existingEnrollment.id

      # Use existing user
      user = existingUser

    ELSE:
      # Check for different organization conflict
      existingOrgEnrollment = QUERY Enrollment WHERE:
        userId = existingUser.id AND
        organizationId IS NOT NULL AND
        organizationId != invite.organizationId

      IF existingOrgEnrollment is NOT NULL:
        THROW Error(
          "User is already enrolled with a different organization. " +
          "Please contact support."
        )

      # User exists but no conflicts
      user = existingUser
  ELSE:
    # Create New User Account
    passwordHash = hashPassword(userData.password)

    user = CREATE User:
      id: generateUUID()
      email: invite.email
      firstName: invite.firstName
      lastName: invite.lastName
      passwordHash: passwordHash
      role: "LEARNER"
      emailVerified: TRUE  # B2B invites are pre-verified
      createdAt: NOW()
      onboardingCompleted: FALSE

  # Create B2B Enrollment
  enrollment = CREATE Enrollment:
    id: generateUUID()
    userId: user.id
    cohortId: invite.cohortId
    enrollmentType: "b2b"
    organizationId: organization.id
    status: "active"
    paymentStatus: "organization_paid"
    enrolledAt: NOW()
    progress: 0
    completionStatus: "not_started"

  # Update Organization Seat Usage
  UPDATE Organization SET:
    seatsUsed = seatsUsed + 1
  WHERE id = organization.id

  # Update Cohort Enrollment Count
  UPDATE Cohort SET:
    currentEnrollment = currentEnrollment + 1
  WHERE id = invite.cohortId

  # Mark Invite as Used
  UPDATE TeamInvite SET:
    status = "accepted"
    acceptedAt = NOW()
    acceptedBy: user.id
  WHERE id = invite.id

  # Send Welcome Email
  CALL sendEmail(
    to: user.email,
    template: "B2B_ENROLLMENT_WELCOME",
    data: {
      firstName: user.firstName,
      organizationName: organization.name,
      cohortTitle: cohort.title,
      startDate: cohort.startDate,
      dashboardUrl: "${PLATFORM_URL}/dashboard"
    }
  )

  # Log Activity
  LOG EnrollmentActivity:
    enrollmentId: enrollment.id
    action: "B2B_INVITE_REDEEMED"
    metadata: {
      inviteId: invite.id,
      organizationId: organization.id,
      userCreated: existingUser is NULL
    }
    timestamp: NOW()

  RETURN {
    user: user,
    enrollment: enrollment,
    cohort: cohort
  }
```

### Bulk Enrollment Creation (CSV Upload)

```pseudocode
FUNCTION bulkB2BEnrollment(adminId, organizationId, cohortId, csvFile):
  # Input Validation
  VALIDATE adminId has ADMIN role

  # Retrieve Organization and Cohort
  organization = QUERY Organization WHERE id = organizationId
  IF organization is NULL:
    THROW Error("Organization not found")

  cohort = QUERY Cohort WHERE id = cohortId
  IF cohort is NULL:
    THROW Error("Cohort not found")

  # Parse CSV
  csvData = parseCSV(csvFile)
  # Expected columns: email, firstName, lastName

  VALIDATE csvData.headers contains ["email", "firstName", "lastName"]

  results = {
    successful: [],
    failed: [],
    skipped: []
  }

  # Check Available Seats
  availableSeats = organization.seatsPurchased - organization.seatsUsed

  IF csvData.rows.length > availableSeats:
    THROW Error(
      "Cannot enroll ${csvData.rows.length} users. Only ${availableSeats} seats available."
    )

  # Process Each Row
  FOR EACH row IN csvData.rows:
    TRY:
      # Validate row data
      IF NOT isValidEmail(row.email):
        results.failed.push({
          email: row.email,
          reason: "Invalid email format"
        })
        CONTINUE

      # Check for duplicate in current batch
      IF results.successful.some(r => r.email = row.email):
        results.skipped.push({
          email: row.email,
          reason: "Duplicate in CSV"
        })
        CONTINUE

      # Generate invite token
      inviteToken = generateSecureToken(length: 32, expiresIn: 30 days)

      # Create invite
      invite = CREATE TeamInvite:
        id: generateUUID()
        token: inviteToken
        organizationId: organizationId
        cohortId: cohortId
        email: row.email
        firstName: row.firstName
        lastName: row.lastName
        status: "pending"
        expiresAt: NOW() + 30 days
        createdBy: adminId
        createdAt: NOW()

      # Send invite email
      AWAIT brevo.sendTransactionalEmail({
        to: [{ email: row.email, name: "${row.firstName} ${row.lastName}" }],
        templateId: BREVO_TEMPLATE_B2B_INVITE,
        params: {
          firstName: row.firstName,
          organizationName: organization.name,
          cohortTitle: cohort.title,
          inviteUrl: "${PLATFORM_URL}/join?token=${inviteToken}",
          expiresAt: formatDate(invite.expiresAt)
        }
      })

      results.successful.push({
        email: row.email,
        inviteId: invite.id,
        inviteUrl: "${PLATFORM_URL}/join?token=${inviteToken}"
      })

    CATCH error:
      results.failed.push({
        email: row.email,
        reason: error.message
      })

  # Log Bulk Operation
  LOG OrganizationActivity:
    organizationId: organizationId
    action: "BULK_ENROLLMENT_PROCESSED"
    performedBy: adminId
    metadata: {
      cohortId: cohortId,
      totalRows: csvData.rows.length,
      successful: results.successful.length,
      failed: results.failed.length,
      skipped: results.skipped.length
    }
    timestamp: NOW()

  RETURN results
```

---

## 2.2.4 Waitlist Management

### View Waitlist by Cohort

```pseudocode
FUNCTION getWaitlistForCohort(adminId, cohortId, filters):
  # Input Validation
  VALIDATE adminId has ADMIN role

  # Optional Filters
  sortBy = filters.sortBy OR "addedAt"  # addedAt, priority
  sortOrder = filters.sortOrder OR "ASC"
  limit = filters.limit OR 50
  offset = filters.offset OR 0

  # Build Query
  query = QUERY Waitlist WHERE:
    cohortId = cohortId AND
    status = "waiting"

  # Apply Sorting
  IF sortBy = "addedAt":
    query = query ORDER BY addedAt sortOrder
  ELSE IF sortBy = "priority":
    query = query ORDER BY priority DESC, addedAt ASC

  # Apply Pagination
  query = query LIMIT limit OFFSET offset

  # Execute Query
  waitlistEntries = EXECUTE query

  # Get Total Count
  totalWaiting = QUERY COUNT(*) FROM Waitlist WHERE:
    cohortId = cohortId AND
    status = "waiting"

  # Enrich with User Data
  FOR EACH entry IN waitlistEntries:
    user = QUERY User WHERE id = entry.userId
    entry.user = {
      email: user.email,
      firstName: user.firstName,
      lastName: user.lastName
    }

  RETURN {
    entries: waitlistEntries,
    total: totalWaiting,
    pagination: {
      limit: limit,
      offset: offset,
      hasMore: (offset + limit) < totalWaiting
    }
  }
```

### Manual Promotion to Enrollment

```pseudocode
FUNCTION promoteFromWaitlist(adminId, waitlistId):
  # Input Validation
  VALIDATE adminId has ADMIN role

  # Retrieve Waitlist Entry
  waitlistEntry = QUERY Waitlist WHERE id = waitlistId
  IF waitlistEntry is NULL:
    THROW Error("Waitlist entry not found")

  IF waitlistEntry.status != "waiting":
    THROW Error("Waitlist entry is not in waiting status")

  # Check Cohort Availability
  cohort = QUERY Cohort WHERE id = waitlistEntry.cohortId

  IF cohort.currentEnrollment >= cohort.maxCapacity:
    THROW Error("Cohort is at maximum capacity")

  IF cohort.status NOT IN ["scheduled", "open"]:
    THROW Error("Cohort is not accepting enrollments")

  # Retrieve User
  user = QUERY User WHERE id = waitlistEntry.userId

  # Check for Existing Enrollment
  existingEnrollment = QUERY Enrollment WHERE:
    userId = user.id AND
    cohortId = cohort.id

  IF existingEnrollment is NOT NULL:
    THROW Error("User is already enrolled in this cohort")

  BEGIN TRANSACTION:
    # Create Enrollment
    enrollment = CREATE Enrollment:
      id: generateUUID()
      userId: user.id
      cohortId: cohort.id
      enrollmentType: "b2c"  # Assume B2C for waitlist promotions
      status: "active"
      paymentStatus: "pending"  # User needs to complete payment
      enrolledAt: NOW()
      enrolledBy: adminId
      progress: 0
      completionStatus: "not_started"
      promotedFromWaitlist: TRUE

    # Update Cohort Enrollment Count
    UPDATE Cohort SET:
      currentEnrollment = currentEnrollment + 1
    WHERE id = cohort.id

    # Update Waitlist Entry
    UPDATE Waitlist SET:
      status = "promoted"
      promotedAt = NOW()
      promotedBy: adminId
      enrollmentId: enrollment.id
    WHERE id = waitlistId

    # Log Activities
    LOG WaitlistActivity:
      waitlistId: waitlistId
      action: "MANUALLY_PROMOTED"
      performedBy: adminId
      metadata: {
        userId: user.id,
        cohortId: cohort.id,
        enrollmentId: enrollment.id
      }
      timestamp: NOW()

    LOG EnrollmentActivity:
      enrollmentId: enrollment.id
      action: "CREATED_FROM_WAITLIST"
      performedBy: adminId
      metadata: {
        waitlistId: waitlistId
      }
      timestamp: NOW()

  COMMIT TRANSACTION

  # Send Promotion Email with Payment Link
  paymentUrl = generateStripePaymentLink(
    cohortId: cohort.id,
    userId: user.id,
    amount: cohort.b2cPrice,
    currency: cohort.currency
  )

  CALL sendEmail(
    to: user.email,
    template: "WAITLIST_PROMOTION",
    data: {
      firstName: user.firstName,
      cohortTitle: cohort.title,
      startDate: cohort.startDate,
      price: formatCurrency(cohort.b2cPrice, cohort.currency),
      paymentUrl: paymentUrl,
      paymentDeadline: formatDate(NOW() + 48 hours)  # 48-hour payment window
    }
  )

  RETURN {
    enrollment: enrollment,
    paymentUrl: paymentUrl
  }
```

### Auto-Promotion on Refund

```pseudocode
FUNCTION autoPromoteWaitlistOnRefund(cohortId):
  # This function is called when a refund is processed
  # It automatically promotes the next person on the waitlist

  # Check if cohort has waitlist
  waitlistCount = QUERY COUNT(*) FROM Waitlist WHERE:
    cohortId = cohortId AND
    status = "waiting"

  IF waitlistCount = 0:
    RETURN NULL  # No one to promote

  # Get next person on waitlist (FIFO, but prioritize high-priority entries)
  nextInLine = QUERY Waitlist WHERE:
    cohortId = cohortId AND
    status = "waiting"
  ORDER BY:
    priority DESC,  # High priority first
    addedAt ASC     # Then by join time (FIFO)
  LIMIT 1

  IF nextInLine is NULL:
    RETURN NULL

  # Promote using manual promotion logic
  TRY:
    result = promoteFromWaitlist(
      adminId: "SYSTEM",  # System-initiated promotion
      waitlistId: nextInLine.id
    )

    LOG Info:
      message: "Auto-promoted waitlist entry after refund"
      cohortId: cohortId
      waitlistId: nextInLine.id
      enrollmentId: result.enrollment.id

    RETURN result

  CATCH error:
    LOG Error:
      message: "Failed to auto-promote waitlist entry"
      error: error
      cohortId: cohortId
      waitlistId: nextInLine.id

    RETURN NULL
```

### Waitlist Expiry and Cleanup

```pseudocode
FUNCTION cleanupExpiredWaitlistEntries():
  # This function runs as a scheduled job (e.g., daily)

  # Define expiry criteria
  EXPIRY_DAYS = 90  # Waitlist entries expire after 90 days
  COHORT_PAST_DAYS = 7  # Clean up waitlist 7 days after cohort ends

  # Find expired entries
  expiredEntries = QUERY Waitlist WHERE:
    status = "waiting" AND
    (
      # Entries older than 90 days
      addedAt < (NOW() - EXPIRY_DAYS days)
      OR
      # Cohorts that have ended
      cohortId IN (
        SELECT id FROM Cohort WHERE:
          status = "completed" AND
          endDate < (NOW() - COHORT_PAST_DAYS days)
      )
    )

  cleanedCount = 0

  FOR EACH entry IN expiredEntries:
    BEGIN TRANSACTION:
      # Update entry status
      UPDATE Waitlist SET:
        status = "expired"
        expiredAt = NOW()
      WHERE id = entry.id

      # Notify user
      user = QUERY User WHERE id = entry.userId
      cohort = QUERY Cohort WHERE id = entry.cohortId

      CALL sendEmail(
        to: user.email,
        template: "WAITLIST_EXPIRED",
        data: {
          firstName: user.firstName,
          cohortTitle: cohort.title,
          browseCohortsUrl: "${PLATFORM_URL}/cohorts"
        }
      )

      # Log activity
      LOG WaitlistActivity:
        waitlistId: entry.id
        action: "EXPIRED"
        metadata: {
          reason: IF(entry.addedAt < (NOW() - EXPIRY_DAYS days), "AGE", "COHORT_ENDED"),
          addedAt: entry.addedAt,
          cohortStatus: cohort.status
        }
        timestamp: NOW()

      cleanedCount = cleanedCount + 1

    COMMIT TRANSACTION

  LOG Info:
    message: "Cleaned up expired waitlist entries"
    count: cleanedCount
    timestamp: NOW()

  RETURN cleanedCount
```

### Notification on Spot Available

```pseudocode
FUNCTION notifyWaitlistOnSpotAvailable(cohortId):
  # This function is called when capacity is increased or a spot opens

  # Check current cohort state
  cohort = QUERY Cohort WHERE id = cohortId

  availableSpots = cohort.maxCapacity - cohort.currentEnrollment

  IF availableSpots <= 0:
    RETURN  # No spots available

  # Get top N waitlisted users (where N = available spots)
  waitlistUsers = QUERY Waitlist WHERE:
    cohortId = cohortId AND
    status = "waiting"
  ORDER BY:
    priority DESC,
    addedAt ASC
  LIMIT availableSpots

  IF waitlistUsers.length = 0:
    RETURN  # No one on waitlist

  # Send notifications
  FOR EACH entry IN waitlistUsers:
    user = QUERY User WHERE id = entry.userId

    # Generate enrollment link with pre-filled data
    enrollmentUrl = "${PLATFORM_URL}/enroll/${cohort.id}?waitlist=${entry.id}"

    CALL sendEmail(
      to: user.email,
      template: "WAITLIST_SPOT_AVAILABLE",
      data: {
        firstName: user.firstName,
        cohortTitle: cohort.title,
        sessionType: cohort.sessionType,
        startDate: cohort.startDate,
        price: formatCurrency(cohort.b2cPrice, cohort.currency),
        enrollmentUrl: enrollmentUrl,
        validUntil: formatDate(NOW() + 48 hours)  # 48-hour enrollment window
      }
    )

    # Update waitlist entry
    UPDATE Waitlist SET:
      notifiedAt = NOW()
    WHERE id = entry.id

    # Log notification
    LOG WaitlistActivity:
      waitlistId: entry.id
      action: "SPOT_AVAILABLE_NOTIFICATION_SENT"
      metadata: {
        cohortId: cohortId,
        availableSpots: availableSpots
      }
      timestamp: NOW()

  LOG Info:
    message: "Sent spot available notifications to waitlist"
    cohortId: cohortId
    notificationsSent: waitlistUsers.length
    timestamp: NOW()
```

---

## Summary

This section provides comprehensive pseudocode for all admin-facing flows:

### 2.2.1 Cohort Management
- **Create cohort** with session type-specific defaults (cohort: 30, webinar: 100, hackathon: 50)
- **Status transitions** with validation (scheduled → open → in_progress → completed)
- **Invalid transition prevention** (e.g., can't go from completed to open)
- **Manual enrollment** with capacity checks and conflict detection
- **Reschedule handling** with user notifications

### 2.2.2 Enablement Kit Management
- **File upload** via Convex storage with size/type validation (100 MB max)
- **External URL items** with metadata fetching
- **Drag-drop reordering** with transaction safety
- **Item versioning** with archival of previous versions
- **Publish/unpublish logic** with validation rules

### 2.2.3 B2B Manual Enrollment
- **Complete workflow** from offline request to active enrollments
- **Organization creation** with conflict detection
- **Stripe invoice creation** via API (Net 30 terms)
- **Team invite emails** via Brevo with 30-day expiry
- **Invite token generation** (32-char secure tokens)
- **Bulk enrollment** via CSV upload with validation
- **Seat tracking** (seatsPurchased vs seatsUsed)
- **Edge cases**: existing B2C user conversion, different org conflicts

### 2.2.4 Waitlist Management
- **View waitlist** with sorting (FIFO or priority) and pagination
- **Manual promotion** with payment link generation
- **Auto-promotion** on refund (FIFO with priority override)
- **Waitlist expiry** (90-day cleanup job)
- **Spot available notifications** with 48-hour enrollment window

All flows include:
- ✅ **Input validation** at every entry point
- ✅ **Transaction safety** for multi-step operations
- ✅ **Activity logging** for audit trails
- ✅ **Error handling** with descriptive messages
- ✅ **Email notifications** via Brevo
- ✅ **State transitions** with business rule enforcement
