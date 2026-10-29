package com.example.dodroidai.ai.attachments

import com.example.dodroidai.ai.model.AttachmentKind
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class AttachmentLimitsTest {

    @Test
    fun `mime types map to kinds`() {
        assertEquals(AttachmentKind.IMAGE, AttachmentLimits.kindOf("image/png"))
        assertEquals(AttachmentKind.PDF, AttachmentLimits.kindOf("application/pdf"))
        assertEquals(AttachmentKind.TEXT, AttachmentLimits.kindOf("text/plain"))
        assertEquals(AttachmentKind.OTHER, AttachmentLimits.kindOf("application/zip"))
    }

    @Test
    fun `supported formats`() {
        assertEquals(true, AttachmentLimits.isSupported("image/jpeg"))
        assertEquals(true, AttachmentLimits.isSupported("application/pdf"))
        assertEquals(true, AttachmentLimits.isSupported("text/plain"))
        assertEquals(false, AttachmentLimits.isSupported("application/msword"))
    }

    @Test
    fun `validate rejects too many attachments`() {
        val rejection = AttachmentLimits.validateForAdd(
            existingCount = AttachmentLimits.MAX_ATTACHMENTS_PER_MESSAGE,
            size = 1024,
            mimeType = "image/jpeg"
        )
        assertEquals(AttachmentRejection.TOO_MANY, rejection)
    }

    @Test
    fun `validate rejects oversized files`() {
        val rejection = AttachmentLimits.validateForAdd(
            existingCount = 0,
            size = AttachmentLimits.MAX_SOURCE_FILE_BYTES + 1,
            mimeType = "application/pdf"
        )
        assertEquals(AttachmentRejection.TOO_LARGE, rejection)
    }

    @Test
    fun `validate rejects unsupported formats`() {
        val rejection = AttachmentLimits.validateForAdd(
            existingCount = 0,
            size = 1024,
            mimeType = "application/msword"
        )
        assertEquals(AttachmentRejection.UNSUPPORTED, rejection)
    }

    @Test
    fun `validate accepts a supported file`() {
        val rejection = AttachmentLimits.validateForAdd(
            existingCount = 0,
            size = 1024,
            mimeType = "text/plain"
        )
        assertNull(rejection)
    }

    @Test
    fun `to chat attachment carries metadata`() {
        val attachment = AttachmentLimits.toChatAttachment(
            uri = "content://test/1",
            name = "a.png",
            mimeType = "image/png",
            size = 42L
        )
        assertEquals("content://test/1", attachment.uri)
        assertEquals(AttachmentKind.IMAGE, attachment.kind)
        assertEquals(42L, attachment.size)
    }
}
