# 2.7 Content Management & Publishing Flows

## 2.7.1 Blog Post Authoring Flow (BlockNote + Convex Sync)

```pseudocode
FLOW: BLOG_POST_AUTHORING
EDITOR: BlockNote (Notion-style rich text)
SYNC: @convex-dev/prosemirror-sync (real-time collaborative editing)

// ========================================
// CREATE NEW BLOG POST
// ========================================

MUTATION: createBlogPost
ACCESS: Authenticated (role: instructor, admin)

FUNCTION createBlogPost(title, category):
  userId = ctx.userId

  // Validate permissions
  IF NOT hasPermission(userId, "content.create"):
    THROW UnauthorizedError("User cannot create content")

  // Create empty ProseMirror document
  initialDoc = {
    type: "doc",
    content: [
      {
        type: "heading",
        attrs: { level: 1 },
        content: [{ type: "text", text: title }]
      },
      {
        type: "paragraph",
        content: []
      }
    ]
  }

  // Create blog post record
  TRY:
    TRANSACTION:
      postId = db.blogPosts.insert({
        title: title,
        slug: generateSlug(title),
        category: category,
        authorId: userId,
        status: "draft",
        content: initialDoc,
        version: 1,
        seoMetadata: {
          metaTitle: title,
          metaDescription: "",
          ogImage: null,
          keywords: []
        },
        publishedAt: null,
        scheduledFor: null,
        createdAt: now(),
        updatedAt: now()
      })

      // Initialize ProseMirror sync document
      syncDocId = prosemirrorSync.createDocument({
        documentId: "blog-" + postId,
        initialContent: initialDoc,
        version: 1
      })

      // Link sync document to blog post
      db.blogPosts.update(postId, {
        syncDocumentId: syncDocId
      })

      // Create version history entry
      db.contentVersions.insert({
        contentId: postId,
        contentType: "blog_post",
        version: 1,
        content: initialDoc,
        author: userId,
        changeDescription: "Initial creation",
        createdAt: now()
      })

    LOG.info("Blog post created: " + postId + " by user " + userId)

    RETURN {
      postId: postId,
      syncDocumentId: syncDocId,
      slug: generateSlug(title)
    }

  CATCH error:
    THROW ContentCreationError("Failed to create blog post: " + error.message)

// ========================================
// REAL-TIME COLLABORATIVE EDITING
// ========================================

// BlockNote editor initialization (client-side)
COMPONENT: BlogPostEditor

FUNCTION initializeEditor(postId):
  // Fetch blog post data
  post = useQuery(api.blogPosts.getBlogPost, { postId: postId })

  // Initialize ProseMirror sync
  editor = useBlockNote({
    // Convex real-time sync
    collaboration: {
      provider: convexProvider,
      documentId: post.syncDocumentId,
      user: {
        id: currentUser.id,
        name: currentUser.name,
        color: generateUserColor(currentUser.id)
      }
    },

    // Auto-save on changes
    onEditorContentChange: (editor) => {
      debouncedAutoSave(postId, editor.document)
    },

    // Media upload handler
    uploadFile: async (file) => {
      return uploadToMediaLibrary(file)
    }
  })

  RETURN editor

// Auto-save mutation (debounced 2 seconds)
MUTATION: autoSaveBlogPost
ACCESS: Authenticated

FUNCTION autoSaveBlogPost(postId, content):
  userId = ctx.userId
  post = db.blogPosts.get(postId)

  // Verify author or has edit permission
  IF post.authorId !== userId AND NOT hasPermission(userId, "content.edit_any"):
    THROW UnauthorizedError("Cannot edit this post")

  // Update content
  db.blogPosts.update(postId, {
    content: content,
    updatedAt: now(),
    updatedBy: userId
  })

  // ProseMirror sync handles conflict resolution automatically

  RETURN { success: true, savedAt: now() }

// ========================================
// ADD MEDIA FROM LIBRARY
// ========================================

QUERY: searchMediaLibrary
ACCESS: Authenticated

FUNCTION searchMediaLibrary(query, filters):
  // Build search query
  mediaQuery = db.media.query({})

  // Apply filters
  IF filters.type:
    mediaQuery = mediaQuery.filter({ mimeType: { $startsWith: filters.type + "/" } })

  IF filters.folder:
    mediaQuery = mediaQuery.filter({ folderId: filters.folder })

  IF query:
    mediaQuery = mediaQuery.filter({
      $or: [
        { filename: { $contains: query } },
        { alt: { $contains: query } },
        { tags: { $contains: query } }
      ]
    })

  // Execute with pagination
  media = mediaQuery
    .order("createdAt", "desc")
    .paginate(filters.page || 1, filters.pageSize || 20)

  RETURN media

// Insert media into BlockNote editor (client-side)
FUNCTION insertMediaIntoEditor(editor, mediaItem):
  SWITCH mediaItem.mimeType:
    CASE "image/*":
      editor.insertBlocks([{
        type: "image",
        props: {
          url: mediaItem.url,
          alt: mediaItem.alt,
          caption: mediaItem.caption
        }
      }], editor.getTextCursorPosition())

    CASE "video/*":
      editor.insertBlocks([{
        type: "video",
        props: {
          url: mediaItem.url,
          caption: mediaItem.caption
        }
      }], editor.getTextCursorPosition())

    CASE "application/pdf":
      editor.insertBlocks([{
        type: "file",
        props: {
          url: mediaItem.url,
          name: mediaItem.filename,
          size: mediaItem.size
        }
      }], editor.getTextCursorPosition())

// ========================================
// SEO METADATA EDITING
// ========================================

MUTATION: updateBlogPostSEO
ACCESS: Authenticated

FUNCTION updateBlogPostSEO(postId, seoData):
  userId = ctx.userId
  post = db.blogPosts.get(postId)

  // Verify permissions
  IF post.authorId !== userId AND NOT hasPermission(userId, "content.edit_any"):
    THROW UnauthorizedError("Cannot edit this post")

  // Validate SEO data
  TRY:
    validateSEOMetadata(seoData)
  CATCH error:
    THROW ValidationError("Invalid SEO metadata: " + error.message)

  // Update SEO metadata
  db.blogPosts.update(postId, {
    seoMetadata: {
      metaTitle: seoData.metaTitle || post.title,
      metaDescription: seoData.metaDescription,
      ogImage: seoData.ogImage,
      ogTitle: seoData.ogTitle || seoData.metaTitle,
      ogDescription: seoData.ogDescription || seoData.metaDescription,
      keywords: seoData.keywords || [],
      canonicalUrl: seoData.canonicalUrl,
      noIndex: seoData.noIndex || false,
      structuredData: generateBlogStructuredData(post, seoData)
    },
    updatedAt: now()
  })

  RETURN { success: true }

// Helper: Validate SEO metadata
FUNCTION validateSEOMetadata(seoData):
  // Meta title length check
  IF seoData.metaTitle AND seoData.metaTitle.length > 60:
    THROW ValidationError("Meta title should be 60 characters or less")

  // Meta description length check
  IF seoData.metaDescription AND seoData.metaDescription.length > 160:
    THROW ValidationError("Meta description should be 160 characters or less")

  // Keywords validation
  IF seoData.keywords AND seoData.keywords.length > 10:
    THROW ValidationError("Maximum 10 keywords allowed")

// Helper: Generate structured data (JSON-LD)
FUNCTION generateBlogStructuredData(post, seoData):
  author = db.users.get(post.authorId)

  RETURN {
    "@context": "https://schema.org",
    "@type": "BlogPosting",
    "headline": seoData.metaTitle || post.title,
    "description": seoData.metaDescription,
    "image": seoData.ogImage,
    "author": {
      "@type": "Person",
      "name": author.name
    },
    "publisher": {
      "@type": "Organization",
      "name": "AI Enablement Academy",
      "logo": {
        "@type": "ImageObject",
        "url": SITE_URL + "/logo.png"
      }
    },
    "datePublished": post.publishedAt,
    "dateModified": post.updatedAt,
    "mainEntityOfPage": {
      "@type": "WebPage",
      "@id": SITE_URL + "/blog/" + post.slug
    }
  }

// ========================================
// PREVIEW MODE
// ========================================

QUERY: getBlogPostPreview
ACCESS: Authenticated

FUNCTION getBlogPostPreview(postId):
  userId = ctx.userId
  post = db.blogPosts.get(postId)

  // Verify permissions (author or has preview permission)
  IF post.authorId !== userId AND NOT hasPermission(userId, "content.preview"):
    THROW UnauthorizedError("Cannot preview this post")

  // Get author details
  author = db.users.get(post.authorId)

  // Render content to HTML (server-side)
  htmlContent = prosemirrorToHTML(post.content)

  RETURN {
    post: {
      ...post,
      htmlContent: htmlContent
    },
    author: {
      name: author.name,
      bio: author.bio,
      avatar: author.avatar
    },
    previewUrl: SITE_URL + "/preview/blog/" + post.id + "?token=" + generatePreviewToken(postId)
  }

// Generate preview token (short-lived, 1 hour)
FUNCTION generatePreviewToken(postId):
  token = jwt.sign(
    {
      postId: postId,
      type: "preview",
      expiresAt: now() + 1.hour
    },
    PREVIEW_TOKEN_SECRET
  )

  RETURN token

// ========================================
// PUBLISH/SCHEDULE WORKFLOW
// ========================================

MUTATION: publishBlogPost
ACCESS: Authenticated

FUNCTION publishBlogPost(postId, publishOptions):
  userId = ctx.userId
  post = db.blogPosts.get(postId)

  // Verify permissions
  IF post.authorId !== userId AND NOT hasPermission(userId, "content.publish"):
    THROW UnauthorizedError("Cannot publish this post")

  // Validate post is ready for publishing
  TRY:
    validatePostForPublishing(post)
  CATCH error:
    THROW PublishError("Post not ready for publishing: " + error.message)

  SWITCH publishOptions.action:
    CASE "publish_now":
      TRANSACTION:
        // Update post status
        db.blogPosts.update(postId, {
          status: "published",
          publishedAt: now(),
          publishedBy: userId,
          scheduledFor: null,
          updatedAt: now()
        })

        // Create version snapshot
        db.contentVersions.insert({
          contentId: postId,
          contentType: "blog_post",
          version: post.version + 1,
          content: post.content,
          author: userId,
          changeDescription: "Published",
          createdAt: now()
        })

        // Trigger post-publish actions
        triggerPostPublishActions(postId)

      LOG.info("Blog post published: " + postId)
      RETURN { status: "published", publishedAt: now() }

    CASE "schedule":
      scheduledTime = publishOptions.scheduledFor

      // Validate scheduled time is in future
      IF scheduledTime <= now():
        THROW ValidationError("Scheduled time must be in the future")

      // Update post with scheduled time
      db.blogPosts.update(postId, {
        status: "scheduled",
        scheduledFor: scheduledTime,
        updatedAt: now()
      })

      LOG.info("Blog post scheduled: " + postId + " for " + scheduledTime)
      RETURN { status: "scheduled", scheduledFor: scheduledTime }

    CASE "unpublish":
      db.blogPosts.update(postId, {
        status: "draft",
        publishedAt: null,
        updatedAt: now()
      })

      LOG.info("Blog post unpublished: " + postId)
      RETURN { status: "draft" }

// Validation helper
FUNCTION validatePostForPublishing(post):
  // Must have title
  IF NOT post.title OR post.title.trim().length === 0:
    THROW ValidationError("Post must have a title")

  // Must have content
  IF NOT post.content OR isEmptyDocument(post.content):
    THROW ValidationError("Post must have content")

  // Must have category
  IF NOT post.category:
    THROW ValidationError("Post must have a category")

  // SEO metadata recommended
  IF NOT post.seoMetadata.metaDescription:
    LOG.warn("Publishing without meta description (SEO warning)")

  // Featured image recommended
  IF NOT extractFeaturedImage(post.content):
    LOG.warn("Publishing without featured image")

// Post-publish actions
FUNCTION triggerPostPublishActions(postId):
  post = db.blogPosts.get(postId)

  // Generate static page (if SSG enabled)
  IF ENABLE_SSG:
    triggerStaticGeneration(postId)

  // Clear cache
  clearCacheForPost(postId)

  // Send notifications to subscribers
  notifySubscribers(postId)

  // Submit to search index
  submitToSearchIndex(postId)

  // Trigger outbound webhooks
  triggerWebhookEvent("blog_post.published", {
    postId: postId,
    slug: post.slug,
    title: post.title,
    publishedAt: post.publishedAt
  })

// ========================================
// VERSION HISTORY
// ========================================

QUERY: getBlogPostVersionHistory
ACCESS: Authenticated

FUNCTION getBlogPostVersionHistory(postId):
  userId = ctx.userId
  post = db.blogPosts.get(postId)

  // Verify permissions
  IF post.authorId !== userId AND NOT hasPermission(userId, "content.view_history"):
    THROW UnauthorizedError("Cannot view version history")

  // Fetch all versions
  versions = db.contentVersions.query({
    contentId: postId,
    contentType: "blog_post"
  }).order("createdAt", "desc")

  // Enrich with author details
  enrichedVersions = versions.map(version => {
    author = db.users.get(version.author)

    RETURN {
      ...version,
      authorName: author.name,
      authorAvatar: author.avatar
    }
  })

  RETURN enrichedVersions

MUTATION: restoreBlogPostVersion
ACCESS: Authenticated

FUNCTION restoreBlogPostVersion(postId, versionId):
  userId = ctx.userId
  post = db.blogPosts.get(postId)
  version = db.contentVersions.get(versionId)

  // Verify permissions
  IF post.authorId !== userId AND NOT hasPermission(userId, "content.restore_version"):
    THROW UnauthorizedError("Cannot restore version")

  // Verify version belongs to this post
  IF version.contentId !== postId:
    THROW ValidationError("Version does not belong to this post")

  TRANSACTION:
    // Create snapshot of current state before restore
    db.contentVersions.insert({
      contentId: postId,
      contentType: "blog_post",
      version: post.version + 1,
      content: post.content,
      author: userId,
      changeDescription: "Snapshot before restore to version " + version.version,
      createdAt: now()
    })

    // Restore version content
    db.blogPosts.update(postId, {
      content: version.content,
      version: post.version + 2,
      updatedAt: now(),
      updatedBy: userId
    })

    // Update ProseMirror sync document
    prosemirrorSync.updateDocument(post.syncDocumentId, version.content)

    // Create restore entry
    db.contentVersions.insert({
      contentId: postId,
      contentType: "blog_post",
      version: post.version + 2,
      content: version.content,
      author: userId,
      changeDescription: "Restored version " + version.version,
      createdAt: now()
    })

  LOG.info("Restored blog post " + postId + " to version " + version.version)

  RETURN { success: true, restoredVersion: version.version }
```

## 2.7.2 Landing Page Builder Flow (Puck Visual Editor)

```pseudocode
FLOW: LANDING_PAGE_BUILDER
EDITOR: Puck (React page builder)
SYNC: Convex real-time backend

// ========================================
// CREATE NEW LANDING PAGE
// ========================================

MUTATION: createLandingPage
ACCESS: Authenticated (role: instructor, admin)

FUNCTION createLandingPage(name, templateId):
  userId = ctx.userId

  // Validate permissions
  IF NOT hasPermission(userId, "pages.create"):
    THROW UnauthorizedError("User cannot create landing pages")

  // Load template or start blank
  initialData = templateId ? loadPuckTemplate(templateId) : getBlankPuckData()

  TRY:
    TRANSACTION:
      pageId = db.landingPages.insert({
        name: name,
        slug: generateSlug(name),
        puckData: initialData,
        status: "draft",
        authorId: userId,
        seoMetadata: {
          metaTitle: name,
          metaDescription: "",
          ogImage: null
        },
        publishedAt: null,
        createdAt: now(),
        updatedAt: now()
      })

      // Create version snapshot
      db.contentVersions.insert({
        contentId: pageId,
        contentType: "landing_page",
        version: 1,
        content: initialData,
        author: userId,
        changeDescription: templateId ? "Created from template " + templateId : "Blank page created",
        createdAt: now()
      })

    LOG.info("Landing page created: " + pageId)

    RETURN {
      pageId: pageId,
      slug: generateSlug(name),
      editorUrl: SITE_URL + "/editor/pages/" + pageId
    }

  CATCH error:
    THROW ContentCreationError("Failed to create landing page: " + error.message)

// Helper: Load Puck template
FUNCTION loadPuckTemplate(templateId):
  template = db.puckTemplates.get(templateId)

  IF NOT template:
    THROW NotFoundError("Template not found")

  RETURN template.puckData

// Helper: Blank Puck data structure
FUNCTION getBlankPuckData():
  RETURN {
    content: [],
    root: {
      props: {
        title: "Untitled Page"
      }
    }
  }

// ========================================
// DRAG-DROP COMPONENT EDITING
// ========================================

// Puck editor component (client-side)
COMPONENT: LandingPageEditor

FUNCTION initializePuckEditor(pageId):
  // Fetch page data
  page = useQuery(api.landingPages.getLandingPage, { pageId: pageId })

  // Initialize Puck editor
  editor = usePuck({
    // Real-time sync with Convex
    data: page.puckData,

    // Auto-save on changes
    onPublish: async (data) => {
      await saveLandingPage(pageId, data)
    },

    // Custom components registry
    components: {
      Hero: HeroComponent,
      Features: FeaturesComponent,
      Testimonials: TestimonialsComponent,
      CTA: CTAComponent,
      PricingTable: PricingTableComponent,
      FAQ: FAQComponent,
      ContactForm: ContactFormComponent,
      RichText: RichTextComponent,
      Image: ImageComponent,
      Video: VideoComponent,
      Spacer: SpacerComponent
      // ... more components
    },

    // Component configuration
    config: {
      categories: {
        layout: ["Hero", "Features", "Spacer"],
        content: ["RichText", "Image", "Video"],
        conversion: ["CTA", "ContactForm", "PricingTable"],
        social: ["Testimonials", "FAQ"]
      }
    }
  })

  RETURN editor

// Auto-save mutation
MUTATION: saveLandingPage
ACCESS: Authenticated

FUNCTION saveLandingPage(pageId, puckData):
  userId = ctx.userId
  page = db.landingPages.get(pageId)

  // Verify permissions
  IF page.authorId !== userId AND NOT hasPermission(userId, "pages.edit_any"):
    THROW UnauthorizedError("Cannot edit this page")

  // Update page data
  db.landingPages.update(pageId, {
    puckData: puckData,
    updatedAt: now(),
    updatedBy: userId
  })

  RETURN { success: true, savedAt: now() }

// ========================================
// CONFIGURE COMPONENT PROPS
// ========================================

// Component prop editing (client-side)
FUNCTION configureComponentProps(componentId, props):
  // Puck handles this via its built-in UI
  // Props are validated against component schema

  EXAMPLE_COMPONENT_CONFIG: HeroComponent
  {
    fields: {
      title: {
        type: "text",
        label: "Headline"
      },
      subtitle: {
        type: "textarea",
        label: "Subheading"
      },
      backgroundImage: {
        type: "custom",
        label: "Background Image",
        render: ({ value, onChange }) => (
          <MediaLibraryPicker
            value={value}
            onChange={onChange}
            type="image"
          />
        )
      },
      ctaText: {
        type: "text",
        label: "CTA Button Text"
      },
      ctaLink: {
        type: "text",
        label: "CTA Link"
      },
      alignment: {
        type: "select",
        label: "Text Alignment",
        options: [
          { value: "left", label: "Left" },
          { value: "center", label: "Center" },
          { value: "right", label: "Right" }
        ]
      }
    },
    defaultProps: {
      title: "Welcome to Our Platform",
      subtitle: "Transform your business with AI",
      alignment: "center"
    }
  }

// ========================================
// PREVIEW RESPONSIVE BREAKPOINTS
// ========================================

// Responsive preview (client-side)
COMPONENT: ResponsivePreview

FUNCTION renderResponsivePreview(puckData):
  [selectedBreakpoint, setSelectedBreakpoint] = useState("desktop")

  BREAKPOINTS = {
    mobile: { width: 375, height: 667, label: "Mobile" },
    tablet: { width: 768, height: 1024, label: "Tablet" },
    desktop: { width: 1440, height: 900, label: "Desktop" }
  }

  RETURN (
    <div>
      <BreakpointSelector
        breakpoints={BREAKPOINTS}
        selected={selectedBreakpoint}
        onChange={setSelectedBreakpoint}
      />

      <PreviewFrame
        width={BREAKPOINTS[selectedBreakpoint].width}
        height={BREAKPOINTS[selectedBreakpoint].height}
      >
        <Puck.Preview data={puckData} />
      </PreviewFrame>
    </div>
  )

// ========================================
// PUBLISH TO SLUG
// ========================================

MUTATION: publishLandingPage
ACCESS: Authenticated

FUNCTION publishLandingPage(pageId, publishOptions):
  userId = ctx.userId
  page = db.landingPages.get(pageId)

  // Verify permissions
  IF page.authorId !== userId AND NOT hasPermission(userId, "pages.publish"):
    THROW UnauthorizedError("Cannot publish this page")

  // Validate slug availability
  IF publishOptions.slug AND publishOptions.slug !== page.slug:
    existingPage = db.landingPages.query({ slug: publishOptions.slug }).first()

    IF existingPage AND existingPage.id !== pageId:
      THROW ValidationError("Slug already in use")

  TRY:
    TRANSACTION:
      // Update page
      db.landingPages.update(pageId, {
        slug: publishOptions.slug || page.slug,
        status: "published",
        publishedAt: now(),
        publishedBy: userId,
        updatedAt: now()
      })

      // Create version snapshot
      db.contentVersions.insert({
        contentId: pageId,
        contentType: "landing_page",
        version: (page.version || 1) + 1,
        content: page.puckData,
        author: userId,
        changeDescription: "Published",
        createdAt: now()
      })

      // Generate static page (if SSG enabled)
      IF ENABLE_SSG:
        generateStaticPage(pageId)

      // Clear cache
      clearCacheForPage(pageId)

      // Trigger webhooks
      triggerWebhookEvent("landing_page.published", {
        pageId: pageId,
        slug: publishOptions.slug || page.slug,
        publishedAt: now()
      })

    LOG.info("Landing page published: " + pageId)

    RETURN {
      success: true,
      publishedUrl: SITE_URL + "/" + (publishOptions.slug || page.slug)
    }

  CATCH error:
    THROW PublishError("Failed to publish landing page: " + error.message)

// Helper: Generate static page
FUNCTION generateStaticPage(pageId):
  page = db.landingPages.get(pageId)

  // Render Puck data to HTML
  html = renderPuckToHTML(page.puckData, page.seoMetadata)

  // Write to static files (or trigger build)
  writeStaticPage(page.slug, html)

  LOG.info("Static page generated for: " + page.slug)
```

## 2.7.3 Media Library Management Flow

```pseudocode
FLOW: MEDIA_LIBRARY_MANAGEMENT
STORAGE: Convex File Storage + CDN

// ========================================
// UPLOAD FILES
// ========================================

MUTATION: generateUploadUrl
ACCESS: Authenticated

FUNCTION generateUploadUrl():
  userId = ctx.userId

  // Verify permissions
  IF NOT hasPermission(userId, "media.upload"):
    THROW UnauthorizedError("User cannot upload media")

  // Generate upload URL (Convex File Storage)
  uploadUrl = storage.generateUploadUrl()

  RETURN { uploadUrl: uploadUrl }

MUTATION: createMediaItem
ACCESS: Authenticated

FUNCTION createMediaItem(storageId, metadata):
  userId = ctx.userId

  // Get file info from storage
  fileInfo = storage.getMetadata(storageId)

  // Validate file type
  IF NOT isAllowedMimeType(fileInfo.contentType):
    THROW ValidationError("File type not allowed: " + fileInfo.contentType)

  // Validate file size (max 50MB)
  IF fileInfo.size > 50 * 1024 * 1024:
    THROW ValidationError("File size exceeds 50MB limit")

  TRY:
    TRANSACTION:
      mediaId = db.media.insert({
        storageId: storageId,
        filename: metadata.filename || fileInfo.filename,
        mimeType: fileInfo.contentType,
        size: fileInfo.size,
        url: storage.getUrl(storageId),
        folderId: metadata.folderId || null,
        alt: metadata.alt || "",
        caption: metadata.caption || "",
        tags: metadata.tags || [],
        uploadedBy: userId,
        createdAt: now()
      })

      // Process image optimizations (if image)
      IF fileInfo.contentType.startsWith("image/"):
        scheduleImageOptimization(mediaId)

    LOG.info("Media item created: " + mediaId)

    RETURN {
      mediaId: mediaId,
      url: storage.getUrl(storageId)
    }

  CATCH error:
    THROW MediaUploadError("Failed to create media item: " + error.message)

// Helper: Allowed MIME types
FUNCTION isAllowedMimeType(mimeType):
  ALLOWED_TYPES = [
    "image/jpeg",
    "image/png",
    "image/gif",
    "image/webp",
    "image/svg+xml",
    "video/mp4",
    "video/webm",
    "application/pdf",
    "application/zip"
  ]

  RETURN ALLOWED_TYPES.includes(mimeType)

// ========================================
// ORGANIZE IN FOLDERS
// ========================================

MUTATION: createMediaFolder
ACCESS: Authenticated

FUNCTION createMediaFolder(name, parentFolderId):
  userId = ctx.userId

  // Validate permissions
  IF NOT hasPermission(userId, "media.manage_folders"):
    THROW UnauthorizedError("Cannot create folders")

  folderId = db.mediaFolders.insert({
    name: name,
    parentFolderId: parentFolderId || null,
    createdBy: userId,
    createdAt: now()
  })

  RETURN { folderId: folderId }

MUTATION: moveMediaToFolder
ACCESS: Authenticated

FUNCTION moveMediaToFolder(mediaIds, targetFolderId):
  userId = ctx.userId

  // Validate folder exists
  IF targetFolderId:
    folder = db.mediaFolders.get(targetFolderId)
    IF NOT folder:
      THROW NotFoundError("Target folder not found")

  // Move all media items
  FOR mediaId IN mediaIds:
    media = db.media.get(mediaId)

    // Verify permissions
    IF media.uploadedBy !== userId AND NOT hasPermission(userId, "media.manage_any"):
      CONTINUE  // Skip items user doesn't own

    db.media.update(mediaId, {
      folderId: targetFolderId,
      updatedAt: now()
    })

  RETURN { moved: mediaIds.length }

// ========================================
// SEARCH AND FILTER
// ========================================

QUERY: searchMedia
ACCESS: Authenticated

FUNCTION searchMedia(query, filters):
  // Build query
  mediaQuery = db.media.query({})

  // Apply text search
  IF query:
    mediaQuery = mediaQuery.filter({
      $or: [
        { filename: { $contains: query } },
        { alt: { $contains: query } },
        { caption: { $contains: query } },
        { tags: { $contains: query } }
      ]
    })

  // Apply filters
  IF filters.type:
    mediaQuery = mediaQuery.filter({
      mimeType: { $startsWith: filters.type + "/" }
    })

  IF filters.folderId !== undefined:
    mediaQuery = mediaQuery.filter({ folderId: filters.folderId })

  IF filters.uploadedBy:
    mediaQuery = mediaQuery.filter({ uploadedBy: filters.uploadedBy })

  IF filters.dateRange:
    mediaQuery = mediaQuery.filter({
      createdAt: {
        $gte: filters.dateRange.from,
        $lte: filters.dateRange.to
      }
    })

  // Execute with pagination
  media = mediaQuery
    .order("createdAt", "desc")
    .paginate(filters.page || 1, filters.pageSize || 50)

  // Enrich with uploader details
  enrichedMedia = media.map(item => {
    uploader = db.users.get(item.uploadedBy)

    RETURN {
      ...item,
      uploaderName: uploader.name,
      uploaderAvatar: uploader.avatar
    }
  })

  RETURN enrichedMedia

// ========================================
// COPY EMBED CODE
// ========================================

QUERY: getMediaEmbedCode
ACCESS: Authenticated

FUNCTION getMediaEmbedCode(mediaId, embedOptions):
  media = db.media.get(mediaId)

  IF NOT media:
    THROW NotFoundError("Media not found")

  SWITCH media.mimeType:
    CASE "image/*":
      RETURN generateImageEmbedCode(media, embedOptions)

    CASE "video/*":
      RETURN generateVideoEmbedCode(media, embedOptions)

    CASE "application/pdf":
      RETURN generatePDFEmbedCode(media, embedOptions)

    DEFAULT:
      RETURN generateGenericEmbedCode(media)

// Embed code generators
FUNCTION generateImageEmbedCode(media, options):
  width = options.width || "auto"
  height = options.height || "auto"

  RETURN {
    html: `<img src="${media.url}" alt="${media.alt}" width="${width}" height="${height}" />`,
    markdown: `![${media.alt}](${media.url})`,
    blockNote: {
      type: "image",
      props: {
        url: media.url,
        alt: media.alt,
        caption: media.caption
      }
    }
  }

FUNCTION generateVideoEmbedCode(media, options):
  RETURN {
    html: `<video controls width="${options.width || 640}"><source src="${media.url}" type="${media.mimeType}">Your browser does not support the video tag.</video>`,
    blockNote: {
      type: "video",
      props: {
        url: media.url,
        caption: media.caption
      }
    }
  }

FUNCTION generatePDFEmbedCode(media, options):
  RETURN {
    html: `<iframe src="${media.url}" width="${options.width || 800}" height="${options.height || 600}"></iframe>`,
    link: `<a href="${media.url}" target="_blank">${media.filename}</a>`
  }

// ========================================
// DELETE WITH USAGE CHECK
// ========================================

MUTATION: deleteMedia
ACCESS: Authenticated

FUNCTION deleteMedia(mediaId):
  userId = ctx.userId
  media = db.media.get(mediaId)

  // Verify permissions
  IF media.uploadedBy !== userId AND NOT hasPermission(userId, "media.delete_any"):
    THROW UnauthorizedError("Cannot delete this media")

  // Check usage in content
  usage = checkMediaUsage(mediaId)

  IF usage.total > 0:
    // Return usage info for confirmation
    RETURN {
      canDelete: false,
      usageWarning: true,
      usage: usage,
      message: "This media is used in " + usage.total + " content items"
    }

  TRY:
    TRANSACTION:
      // Delete from storage
      storage.delete(media.storageId)

      // Delete record
      db.media.delete(mediaId)

    LOG.info("Media deleted: " + mediaId)

    RETURN { success: true, deleted: true }

  CATCH error:
    THROW MediaDeleteError("Failed to delete media: " + error.message)

// Helper: Check media usage
FUNCTION checkMediaUsage(mediaId):
  media = db.media.get(mediaId)

  // Search in blog posts
  blogPostsUsage = db.blogPosts.query({
    content: { $contains: media.url }
  }).count()

  // Search in landing pages
  landingPagesUsage = db.landingPages.query({
    puckData: { $contains: media.url }
  }).count()

  // Search in courses
  coursesUsage = db.courses.query({
    $or: [
      { thumbnailUrl: media.url },
      { content: { $contains: media.url } }
    ]
  }).count()

  RETURN {
    total: blogPostsUsage + landingPagesUsage + coursesUsage,
    blogPosts: blogPostsUsage,
    landingPages: landingPagesUsage,
    courses: coursesUsage
  }
```

## 2.7.4 Content Collaboration Flow (Real-Time)

```pseudocode
FLOW: CONTENT_COLLABORATION
SYNC: @convex-dev/prosemirror-sync (real-time collaborative editing)

// ========================================
// INVITE COLLABORATORS
// ========================================

MUTATION: inviteCollaborator
ACCESS: Authenticated

FUNCTION inviteCollaborator(contentId, contentType, userEmail, role):
  userId = ctx.userId

  // Get content and verify ownership
  content = getContent(contentId, contentType)

  IF content.authorId !== userId AND NOT hasPermission(userId, "content.manage_collaborators"):
    THROW UnauthorizedError("Cannot invite collaborators to this content")

  // Find user by email
  invitedUser = db.users.query({ email: userEmail }).first()

  IF NOT invitedUser:
    // Send invitation email to non-user
    RETURN sendExternalCollaboratorInvite(contentId, contentType, userEmail, role)

  // Check if already a collaborator
  existing = db.contentCollaborators.query({
    contentId: contentId,
    contentType: contentType,
    userId: invitedUser.id
  }).first()

  IF existing:
    THROW ValidationError("User is already a collaborator")

  TRY:
    TRANSACTION:
      collaboratorId = db.contentCollaborators.insert({
        contentId: contentId,
        contentType: contentType,
        userId: invitedUser.id,
        role: role,  // "editor", "viewer", "commenter"
        invitedBy: userId,
        status: "active",
        createdAt: now()
      })

      // Send notification email
      sendEmail({
        to: invitedUser.email,
        template: "collaborator-invitation",
        data: {
          inviterName: db.users.get(userId).name,
          contentTitle: content.title || content.name,
          contentType: contentType,
          role: role,
          contentUrl: getContentEditUrl(contentId, contentType)
        }
      })

    LOG.info("Collaborator invited: " + invitedUser.id + " to " + contentType + " " + contentId)

    RETURN { success: true, collaboratorId: collaboratorId }

  CATCH error:
    THROW ContentCollaborationError("Failed to invite collaborator: " + error.message)

// ========================================
// REAL-TIME CURSOR PRESENCE
// ========================================

// Client-side presence tracking
COMPONENT: CollaborativeEditor

FUNCTION initializePresence(contentId):
  // Convex real-time presence
  presence = usePresence(api.collaboration.trackPresence, {
    contentId: contentId
  })

  // Update user's cursor position
  [cursorPosition, setCursorPosition] = useState(null)

  // Broadcast cursor position
  useEffect(() => {
    IF cursorPosition:
      presence.update({
        cursor: cursorPosition,
        selection: editor.getSelection(),
        timestamp: Date.now()
      })
  }, [cursorPosition])

  // Render other users' cursors
  RETURN (
    <EditorContainer>
      <BlockNoteEditor
        onSelectionChange={(selection) => setCursorPosition(selection.anchor)}
      />

      {presence.others.map(user => (
        <RemoteCursor
          key={user.id}
          position={user.cursor}
          color={user.color}
          label={user.name}
        />
      ))}
    </EditorContainer>
  )

// Server-side presence tracking
MUTATION: trackPresence
ACCESS: Authenticated

FUNCTION trackPresence(contentId, presenceData):
  userId = ctx.userId

  // Update user's presence
  db.contentPresence.upsert(
    { contentId: contentId, userId: userId },
    {
      contentId: contentId,
      userId: userId,
      cursor: presenceData.cursor,
      selection: presenceData.selection,
      lastActiveAt: now()
    }
  )

  // Clean up stale presence (> 30 seconds)
  db.contentPresence.delete({
    lastActiveAt: { $lt: now() - 30000 }
  })

QUERY: getActiveCollaborators
ACCESS: Authenticated

FUNCTION getActiveCollaborators(contentId):
  // Get active presence (last 30 seconds)
  activePresence = db.contentPresence.query({
    contentId: contentId,
    lastActiveAt: { $gte: now() - 30000 }
  })

  // Enrich with user details
  collaborators = activePresence.map(presence => {
    user = db.users.get(presence.userId)

    RETURN {
      userId: user.id,
      name: user.name,
      avatar: user.avatar,
      color: generateUserColor(user.id),
      cursor: presence.cursor,
      selection: presence.selection
    }
  })

  RETURN collaborators

// ========================================
// COMMENT/SUGGESTION MODE
// ========================================

MUTATION: addComment
ACCESS: Authenticated

FUNCTION addComment(contentId, contentType, comment):
  userId = ctx.userId

  // Verify user has access to content
  IF NOT hasContentAccess(userId, contentId, contentType):
    THROW UnauthorizedError("Cannot comment on this content")

  commentId = db.contentComments.insert({
    contentId: contentId,
    contentType: contentType,
    userId: userId,
    content: comment.content,
    position: comment.position,  // ProseMirror position
    resolved: false,
    createdAt: now()
  })

  // Notify other collaborators
  notifyCollaborators(contentId, contentType, userId, "comment_added", {
    commentId: commentId,
    content: comment.content
  })

  RETURN { commentId: commentId }

MUTATION: addSuggestion
ACCESS: Authenticated

FUNCTION addSuggestion(contentId, contentType, suggestion):
  userId = ctx.userId

  // Verify user has edit permission
  IF NOT hasContentEditPermission(userId, contentId, contentType):
    THROW UnauthorizedError("Cannot suggest edits to this content")

  suggestionId = db.contentSuggestions.insert({
    contentId: contentId,
    contentType: contentType,
    userId: userId,
    originalContent: suggestion.originalContent,
    suggestedContent: suggestion.suggestedContent,
    position: suggestion.position,
    status: "pending",  // "pending", "accepted", "rejected"
    createdAt: now()
  })

  // Notify content owner
  content = getContent(contentId, contentType)
  notifyUser(content.authorId, "suggestion_received", {
    suggestionId: suggestionId,
    contentTitle: content.title || content.name
  })

  RETURN { suggestionId: suggestionId }

MUTATION: resolveSuggestion
ACCESS: Authenticated

FUNCTION resolveSuggestion(suggestionId, action):
  userId = ctx.userId
  suggestion = db.contentSuggestions.get(suggestionId)
  content = getContent(suggestion.contentId, suggestion.contentType)

  // Verify user is content owner
  IF content.authorId !== userId:
    THROW UnauthorizedError("Only content owner can resolve suggestions")

  SWITCH action:
    CASE "accept":
      // Apply suggestion to content
      applySuggestionToContent(suggestion)

      db.contentSuggestions.update(suggestionId, {
        status: "accepted",
        resolvedAt: now(),
        resolvedBy: userId
      })

      LOG.info("Suggestion accepted: " + suggestionId)

    CASE "reject":
      db.contentSuggestions.update(suggestionId, {
        status: "rejected",
        resolvedAt: now(),
        resolvedBy: userId
      })

      LOG.info("Suggestion rejected: " + suggestionId)

  // Notify suggester
  notifyUser(suggestion.userId, "suggestion_resolved", {
    suggestionId: suggestionId,
    action: action
  })

  RETURN { success: true, action: action }

// ========================================
// APPROVAL WORKFLOW
// ========================================

MUTATION: submitForApproval
ACCESS: Authenticated

FUNCTION submitForApproval(contentId, contentType, approvers):
  userId = ctx.userId
  content = getContent(contentId, contentType)

  // Verify user is author or editor
  IF content.authorId !== userId AND NOT isCollaborator(userId, contentId, "editor"):
    THROW UnauthorizedError("Cannot submit for approval")

  TRY:
    TRANSACTION:
      // Create approval request
      approvalId = db.contentApprovals.insert({
        contentId: contentId,
        contentType: contentType,
        submittedBy: userId,
        approvers: approvers,
        status: "pending",
        approvals: [],
        rejections: [],
        createdAt: now()
      })

      // Update content status
      updateContent(contentId, contentType, {
        status: "pending_approval",
        approvalId: approvalId
      })

      // Notify approvers
      FOR approverId IN approvers:
        sendEmail({
          to: db.users.get(approverId).email,
          template: "approval-request",
          data: {
            submitterName: db.users.get(userId).name,
            contentTitle: content.title || content.name,
            contentType: contentType,
            reviewUrl: getContentReviewUrl(contentId, contentType)
          }
        })

    LOG.info("Content submitted for approval: " + contentId)

    RETURN { success: true, approvalId: approvalId }

  CATCH error:
    THROW ContentApprovalError("Failed to submit for approval: " + error.message)

MUTATION: approveContent
ACCESS: Authenticated

FUNCTION approveContent(approvalId, feedback):
  userId = ctx.userId
  approval = db.contentApprovals.get(approvalId)

  // Verify user is an approver
  IF NOT approval.approvers.includes(userId):
    THROW UnauthorizedError("User is not an approver for this content")

  // Check if already approved/rejected
  IF approval.approvals.includes(userId) OR approval.rejections.includes(userId):
    THROW ValidationError("User has already reviewed this content")

  // Add approval
  db.contentApprovals.update(approvalId, {
    approvals: [...approval.approvals, userId],
    feedback: [...(approval.feedback || []), {
      userId: userId,
      action: "approved",
      comment: feedback,
      timestamp: now()
    }]
  })

  // Check if all approvers have approved
  updatedApproval = db.contentApprovals.get(approvalId)

  IF updatedApproval.approvals.length === updatedApproval.approvers.length:
    // All approved - update content status
    db.contentApprovals.update(approvalId, {
      status: "approved",
      approvedAt: now()
    })

    updateContent(updatedApproval.contentId, updatedApproval.contentType, {
      status: "approved"
    })

    // Notify submitter
    notifyUser(updatedApproval.submittedBy, "content_approved", {
      contentId: updatedApproval.contentId,
      contentType: updatedApproval.contentType
    })

  RETURN { success: true, allApproved: updatedApproval.approvals.length === updatedApproval.approvers.length }

// ========================================
// CONFLICT RESOLUTION
// ========================================

// Handled automatically by ProseMirror sync
// Convex ProseMirror sync uses Operational Transformation (OT)
// to merge concurrent edits without conflicts

INTERNAL: ProseMirrorSyncConflictResolution

WHEN multiple users edit simultaneously:
  1. Each user's changes are tracked as "steps" (ProseMirror operations)

  2. Steps are sent to Convex server with version number

  3. Server applies Operational Transformation:
     - Rebase incoming steps against newer steps
     - Transform step positions to account for concurrent edits
     - Ensure all clients converge to same document state

  4. Transformed steps are broadcast to all clients

  5. Clients apply transformed steps and update UI

  RESULT: No merge conflicts, automatic resolution

EXAMPLE_CONFLICT:
  User A: Inserts "Hello" at position 10
  User B: Inserts "World" at position 10

  Resolution:
  - Server receives A's step first
  - Server transforms B's step: position 10 → position 15 (after "Hello")
  - Final document: "Hello World" at position 10
  - Both clients converge to same state
```

## 2.7.5 Content Scheduling Flow

```pseudocode
FLOW: CONTENT_SCHEDULING
EXECUTOR: Convex cron jobs

// ========================================
// SCHEDULE FUTURE PUBLISH
// ========================================

MUTATION: scheduleContentPublish
ACCESS: Authenticated

FUNCTION scheduleContentPublish(contentId, contentType, scheduledFor):
  userId = ctx.userId
  content = getContent(contentId, contentType)

  // Verify permissions
  IF content.authorId !== userId AND NOT hasPermission(userId, contentType + ".schedule"):
    THROW UnauthorizedError("Cannot schedule this content")

  // Validate scheduled time is in future
  IF scheduledFor <= now():
    THROW ValidationError("Scheduled time must be in the future")

  // Validate content is ready for publishing
  validateContentForPublishing(content, contentType)

  // Update content status
  updateContent(contentId, contentType, {
    status: "scheduled",
    scheduledFor: scheduledFor,
    updatedAt: now()
  })

  LOG.info("Content scheduled: " + contentType + " " + contentId + " for " + scheduledFor)

  RETURN {
    success: true,
    scheduledFor: scheduledFor,
    status: "scheduled"
  }

// ========================================
// CRON JOB EXECUTION
// ========================================

CRON: PROCESS_SCHEDULED_CONTENT
SCHEDULE: Every 1 minute
EXECUTOR: Convex built-in scheduler

FUNCTION processScheduledContent():
  currentTime = now()

  // Find all content scheduled for now or earlier
  scheduledBlogPosts = db.blogPosts.query({
    status: "scheduled",
    scheduledFor: { $lte: currentTime }
  })

  scheduledLandingPages = db.landingPages.query({
    status: "scheduled",
    scheduledFor: { $lte: currentTime }
  })

  totalPublished = 0

  // Publish blog posts
  FOR post IN scheduledBlogPosts:
    TRY:
      TRANSACTION:
        // Update status to published
        db.blogPosts.update(post.id, {
          status: "published",
          publishedAt: currentTime,
          scheduledFor: null,
          updatedAt: currentTime
        })

        // Create version snapshot
        db.contentVersions.insert({
          contentId: post.id,
          contentType: "blog_post",
          version: (post.version || 1) + 1,
          content: post.content,
          author: post.authorId,
          changeDescription: "Scheduled publish",
          createdAt: currentTime
        })

        // Trigger post-publish actions
        triggerPostPublishActions(post.id)

        // Send notification to author
        sendEmail({
          to: db.users.get(post.authorId).email,
          template: "content-published-scheduled",
          data: {
            contentTitle: post.title,
            contentType: "Blog Post",
            publishedUrl: SITE_URL + "/blog/" + post.slug,
            publishedAt: currentTime
          }
        })

      totalPublished++
      LOG.info("Scheduled blog post published: " + post.id)

    CATCH error:
      LOG.error("Failed to publish scheduled blog post " + post.id + ": " + error.message)

      // Send error notification to author
      sendEmail({
        to: db.users.get(post.authorId).email,
        template: "content-publish-failed",
        data: {
          contentTitle: post.title,
          contentType: "Blog Post",
          error: error.message
        }
      })

  // Publish landing pages
  FOR page IN scheduledLandingPages:
    TRY:
      TRANSACTION:
        db.landingPages.update(page.id, {
          status: "published",
          publishedAt: currentTime,
          scheduledFor: null,
          updatedAt: currentTime
        })

        // Create version snapshot
        db.contentVersions.insert({
          contentId: page.id,
          contentType: "landing_page",
          version: (page.version || 1) + 1,
          content: page.puckData,
          author: page.authorId,
          changeDescription: "Scheduled publish",
          createdAt: currentTime
        })

        // Generate static page
        IF ENABLE_SSG:
          generateStaticPage(page.id)

        // Send notification
        sendEmail({
          to: db.users.get(page.authorId).email,
          template: "content-published-scheduled",
          data: {
            contentTitle: page.name,
            contentType: "Landing Page",
            publishedUrl: SITE_URL + "/" + page.slug,
            publishedAt: currentTime
          }
        })

      totalPublished++
      LOG.info("Scheduled landing page published: " + page.id)

    CATCH error:
      LOG.error("Failed to publish scheduled landing page " + page.id + ": " + error.message)

  RETURN {
    processed: scheduledBlogPosts.length + scheduledLandingPages.length,
    published: totalPublished
  }

// ========================================
// NOTIFICATION ON PUBLISH
// ========================================

FUNCTION triggerPostPublishNotifications(contentId, contentType):
  content = getContent(contentId, contentType)

  // Notify collaborators
  collaborators = db.contentCollaborators.query({
    contentId: contentId,
    contentType: contentType,
    status: "active"
  })

  FOR collaborator IN collaborators:
    sendEmail({
      to: db.users.get(collaborator.userId).email,
      template: "content-published-collaborator",
      data: {
        contentTitle: content.title || content.name,
        contentType: contentType,
        publishedUrl: getContentPublicUrl(contentId, contentType)
      }
    })

  // Trigger webhooks
  triggerWebhookEvent(contentType + ".published", {
    contentId: contentId,
    publishedAt: now()
  })

  // Post to social media (if configured)
  IF content.autoPostToSocial:
    scheduleSocialMediaPosts(contentId, contentType)

// ========================================
// RESCHEDULE/CANCEL
// ========================================

MUTATION: rescheduleContent
ACCESS: Authenticated

FUNCTION rescheduleContent(contentId, contentType, newScheduledTime):
  userId = ctx.userId
  content = getContent(contentId, contentType)

  // Verify permissions
  IF content.authorId !== userId AND NOT hasPermission(userId, contentType + ".schedule"):
    THROW UnauthorizedError("Cannot reschedule this content")

  // Validate new time is in future
  IF newScheduledTime <= now():
    THROW ValidationError("New scheduled time must be in the future")

  // Update scheduled time
  updateContent(contentId, contentType, {
    scheduledFor: newScheduledTime,
    updatedAt: now()
  })

  LOG.info("Content rescheduled: " + contentType + " " + contentId + " to " + newScheduledTime)

  RETURN { success: true, scheduledFor: newScheduledTime }

MUTATION: cancelScheduledPublish
ACCESS: Authenticated

FUNCTION cancelScheduledPublish(contentId, contentType):
  userId = ctx.userId
  content = getContent(contentId, contentType)

  // Verify permissions
  IF content.authorId !== userId AND NOT hasPermission(userId, contentType + ".schedule"):
    THROW UnauthorizedError("Cannot cancel scheduled publish")

  // Revert to draft
  updateContent(contentId, contentType, {
    status: "draft",
    scheduledFor: null,
    updatedAt: now()
  })

  LOG.info("Scheduled publish canceled: " + contentType + " " + contentId)

  RETURN { success: true, status: "draft" }
```

## 2.7.6 Course Content Integration Flow

```pseudocode
FLOW: COURSE_CONTENT_INTEGRATION

// ========================================
// LINK LESSON TO COURSE
// ========================================

MUTATION: linkLessonToCourse
ACCESS: Authenticated

FUNCTION linkLessonToCourse(lessonId, courseId, moduleId, order):
  userId = ctx.userId
  course = db.courses.get(courseId)

  // Verify permissions
  IF course.instructorId !== userId AND NOT hasPermission(userId, "courses.edit"):
    THROW UnauthorizedError("Cannot modify this course")

  // Validate lesson exists
  lesson = db.lessons.get(lessonId)
  IF NOT lesson:
    THROW NotFoundError("Lesson not found")

  TRY:
    TRANSACTION:
      // Create lesson-course link
      linkId = db.courseLessonLinks.insert({
        courseId: courseId,
        lessonId: lessonId,
        moduleId: moduleId,
        order: order,
        createdBy: userId,
        createdAt: now()
      })

      // Update course structure
      module = db.courseModules.get(moduleId)

      db.courseModules.update(moduleId, {
        lessonIds: [...module.lessonIds, lessonId],
        updatedAt: now()
      })

      // Update lesson metadata
      db.lessons.update(lessonId, {
        courseId: courseId,
        moduleId: moduleId,
        updatedAt: now()
      })

    LOG.info("Lesson linked to course: " + lessonId + " → " + courseId)

    RETURN { success: true, linkId: linkId }

  CATCH error:
    THROW CourseIntegrationError("Failed to link lesson: " + error.message)

// ========================================
// REORDER LESSONS
// ========================================

MUTATION: reorderLessons
ACCESS: Authenticated

FUNCTION reorderLessons(moduleId, lessonOrder):
  userId = ctx.userId
  module = db.courseModules.get(moduleId)
  course = db.courses.get(module.courseId)

  // Verify permissions
  IF course.instructorId !== userId AND NOT hasPermission(userId, "courses.edit"):
    THROW UnauthorizedError("Cannot modify this course")

  // Validate all lessons belong to module
  FOR lessonId IN lessonOrder:
    IF NOT module.lessonIds.includes(lessonId):
      THROW ValidationError("Lesson " + lessonId + " does not belong to this module")

  // Update lesson order
  db.courseModules.update(moduleId, {
    lessonIds: lessonOrder,
    updatedAt: now()
  })

  // Update order in links
  FOR i, lessonId IN lessonOrder:
    db.courseLessonLinks.update({
      courseId: course.id,
      lessonId: lessonId,
      moduleId: moduleId
    }, {
      order: i + 1
    })

  LOG.info("Lessons reordered in module: " + moduleId)

  RETURN { success: true, newOrder: lessonOrder }

// ========================================
// CONTENT ACCESS VALIDATION
// ========================================

QUERY: validateLessonAccess
ACCESS: Authenticated

FUNCTION validateLessonAccess(lessonId, userId):
  lesson = db.lessons.get(lessonId)

  IF NOT lesson:
    THROW NotFoundError("Lesson not found")

  // Check if lesson is part of a course
  IF lesson.courseId:
    course = db.courses.get(lesson.courseId)

    // Check enrollment
    enrollment = db.enrollments.query({
      userId: userId,
      courseId: course.id,
      status: { $in: ["active", "completed"] }
    }).first()

    IF NOT enrollment:
      RETURN {
        hasAccess: false,
        reason: "not_enrolled",
        requiresEnrollment: true,
        courseId: course.id
      }

    // Check access expiry
    IF enrollment.accessExpiryDate AND enrollment.accessExpiryDate < now():
      RETURN {
        hasAccess: false,
        reason: "access_expired",
        expiryDate: enrollment.accessExpiryDate,
        enrollmentId: enrollment.id
      }

    // Check prerequisite completion
    IF lesson.prerequisiteIds AND lesson.prerequisiteIds.length > 0:
      completedLessons = db.lessonProgress.query({
        userId: userId,
        courseId: course.id,
        completed: true
      }).map(p => p.lessonId)

      FOR prerequisiteId IN lesson.prerequisiteIds:
        IF NOT completedLessons.includes(prerequisiteId):
          prerequisite = db.lessons.get(prerequisiteId)

          RETURN {
            hasAccess: false,
            reason: "prerequisite_incomplete",
            prerequisiteLessonId: prerequisiteId,
            prerequisiteLessonTitle: prerequisite.title
          }

    RETURN {
      hasAccess: true,
      enrollment: enrollment
    }

  ELSE:
    // Free lesson or standalone content
    RETURN { hasAccess: true }

// ========================================
// PROGRESS TRACKING INTEGRATION
// ========================================

MUTATION: trackLessonProgress
ACCESS: Authenticated

FUNCTION trackLessonProgress(lessonId, progressData):
  userId = ctx.userId

  // Validate access
  accessCheck = validateLessonAccess(lessonId, userId)

  IF NOT accessCheck.hasAccess:
    THROW UnauthorizedError("No access to this lesson: " + accessCheck.reason)

  lesson = db.lessons.get(lessonId)

  // Update or create progress record
  existingProgress = db.lessonProgress.query({
    userId: userId,
    lessonId: lessonId
  }).first()

  IF existingProgress:
    // Update existing progress
    db.lessonProgress.update(existingProgress.id, {
      progress: progressData.progress,
      lastPosition: progressData.lastPosition,
      timeSpent: existingProgress.timeSpent + progressData.sessionTime,
      completed: progressData.completed || existingProgress.completed,
      completedAt: progressData.completed AND NOT existingProgress.completed ? now() : existingProgress.completedAt,
      updatedAt: now()
    })

    progressId = existingProgress.id
  ELSE:
    // Create new progress record
    progressId = db.lessonProgress.insert({
      userId: userId,
      lessonId: lessonId,
      courseId: lesson.courseId,
      moduleId: lesson.moduleId,
      progress: progressData.progress,
      lastPosition: progressData.lastPosition,
      timeSpent: progressData.sessionTime,
      completed: progressData.completed || false,
      completedAt: progressData.completed ? now() : null,
      createdAt: now(),
      updatedAt: now()
    })

  // Update course progress if lesson completed
  IF progressData.completed AND lesson.courseId:
    updateCourseProgress(userId, lesson.courseId)

  RETURN {
    success: true,
    progressId: progressId,
    completed: progressData.completed
  }

// Helper: Update overall course progress
FUNCTION updateCourseProgress(userId, courseId):
  // Get all lessons in course
  courseLessons = db.courseLessonLinks.query({ courseId: courseId })
  totalLessons = courseLessons.length

  // Get completed lessons
  completedLessons = db.lessonProgress.query({
    userId: userId,
    courseId: courseId,
    completed: true
  }).length

  // Calculate progress percentage
  progressPercentage = (completedLessons / totalLessons) * 100

  // Update enrollment progress
  enrollment = db.enrollments.query({
    userId: userId,
    courseId: courseId
  }).first()

  IF enrollment:
    db.enrollments.update(enrollment.id, {
      progress: progressPercentage,
      completedLessons: completedLessons,
      totalLessons: totalLessons,
      updatedAt: now()
    })

    // Check if course completed
    IF progressPercentage === 100 AND enrollment.status !== "completed":
      db.enrollments.update(enrollment.id, {
        status: "completed",
        completedAt: now()
      })

      // Trigger course completion actions
      triggerCourseCompletionActions(enrollment.id)

// ========================================
// HELPER FUNCTIONS
// ========================================

// Generic content getter
FUNCTION getContent(contentId, contentType):
  SWITCH contentType:
    CASE "blog_post":
      RETURN db.blogPosts.get(contentId)
    CASE "landing_page":
      RETURN db.landingPages.get(contentId)
    CASE "course":
      RETURN db.courses.get(contentId)
    DEFAULT:
      THROW ValidationError("Unknown content type: " + contentType)

// Generic content updater
FUNCTION updateContent(contentId, contentType, updates):
  SWITCH contentType:
    CASE "blog_post":
      db.blogPosts.update(contentId, updates)
    CASE "landing_page":
      db.landingPages.update(contentId, updates)
    CASE "course":
      db.courses.update(contentId, updates)

// URL generators
FUNCTION getContentEditUrl(contentId, contentType):
  SWITCH contentType:
    CASE "blog_post":
      RETURN SITE_URL + "/editor/blog/" + contentId
    CASE "landing_page":
      RETURN SITE_URL + "/editor/pages/" + contentId

FUNCTION getContentPublicUrl(contentId, contentType):
  content = getContent(contentId, contentType)

  SWITCH contentType:
    CASE "blog_post":
      RETURN SITE_URL + "/blog/" + content.slug
    CASE "landing_page":
      RETURN SITE_URL + "/" + content.slug

// ========================================
// ERROR TYPES
// ========================================

ERROR ContentCreationError EXTENDS Error
ERROR ContentSyncError EXTENDS Error
ERROR PublishError EXTENDS Error
ERROR MediaUploadError EXTENDS Error
ERROR VersionConflictError EXTENDS Error
ERROR ContentCollaborationError EXTENDS Error
ERROR ContentApprovalError EXTENDS Error
ERROR CourseIntegrationError EXTENDS Error
```
