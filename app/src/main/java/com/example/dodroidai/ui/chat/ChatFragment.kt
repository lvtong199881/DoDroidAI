package com.example.dodroidai.ui.chat

import android.Manifest
import android.content.ContentValues
import android.content.Context
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.MediaStore
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.view.inputmethod.InputMethodManager
import android.widget.Toast
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.content.ContextCompat
import androidx.fragment.app.Fragment
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.lifecycleScope
import androidx.lifecycle.repeatOnLifecycle
import androidx.recyclerview.widget.LinearLayoutManager
import com.example.dodroidai.DoDroidAIApplication
import com.example.dodroidai.R
import com.example.dodroidai.ui.chat.adapter.ChatMessageAdapter
import com.example.dodroidai.ui.chat.input.ChatAddOptions
import com.example.dodroidai.ui.chat.input.ChatInputBox
import com.example.dodroidai.ui.chat.input.AttachmentItem
import com.example.dodroidai.ui.common.Toolbar
import kotlinx.coroutines.launch

/**
 * 聊天页面 Fragment，显示对话内容
 */
class ChatFragment : Fragment() {

    private var toolbar: Toolbar? = null
    private var chatInputBox: ChatInputBox? = null
    private var chatAddOptions: ChatAddOptions? = null
    private var recyclerView: androidx.recyclerview.widget.RecyclerView? = null
    private var adapter: ChatMessageAdapter? = null

    private val sessionId: String? by lazy { arguments?.getString(ARG_SESSION_ID) }

    private val viewModel: ChatViewModel by lazy {
        androidx.lifecycle.ViewModelProvider(
            this,
            ChatViewModel.Factory(
                DoDroidAIApplication.instance.configManager,
                DoDroidAIApplication.instance.chatRepository,
                sessionId
            )
        )[ChatViewModel::class.java]
    }

    // 拍照
    private var tempCameraUri: Uri? = null
    private val takePictureLauncher = registerForActivityResult(
        ActivityResultContracts.TakePicture()
    ) { success ->
        if (success) {
            tempCameraUri?.let { uri -> addImageAttachment(uri) }
        }
    }

    // 相册选择
    private val pickImageLauncher = registerForActivityResult(
        ActivityResultContracts.GetContent()
    ) { uri ->
        uri?.let { addAttachment(it) }
    }

    // 文件选择
    private val pickFileLauncher = registerForActivityResult(
        ActivityResultContracts.OpenDocument()
    ) { uri ->
        uri?.let { addAttachment(it) }
    }

    // 权限请求
    private val cameraPermissionLauncher = registerForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { isGranted ->
        if (isGranted) {
            launchCamera()
        } else {
            Toast.makeText(context, R.string.camera_permission_denied, Toast.LENGTH_SHORT).show()
        }
    }

    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View {
        return inflater.inflate(R.layout.fragment_chat, container, false)
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        initViews(view)
        setupListeners()
        observeState()
    }

    private fun initViews(view: View) {
        toolbar = view.findViewById(R.id.toolbar)
        chatInputBox = view.findViewById(R.id.chatInputBox)
        chatAddOptions = view.findViewById(R.id.chatAddOptions)
        recyclerView = view.findViewById(R.id.recyclerView)

        adapter = ChatMessageAdapter()
        recyclerView?.layoutManager = LinearLayoutManager(context).apply {
            stackFromEnd = true
        }
        recyclerView?.adapter = adapter

        toolbar?.setTitle(R.string.new_chat)
        toolbar?.setOnBackClickListener {
            parentFragmentManager.popBackStack()
        }
        toolbar?.setRightVisible(false)
    }

    private fun setupListeners() {
        chatInputBox?.onDeepThinkToggle = { _ ->
            hideKeyboard()
        }

        chatInputBox?.onModeSwitch = {
            hideKeyboard()
        }

        chatInputBox?.onAddClick = {
            hideKeyboard()
            val isVisible = !chatInputBox!!.isAddOptionsVisible()
            chatInputBox?.setAddOptionsVisible(isVisible)
            chatAddOptions?.setVisible(isVisible)
        }

        chatInputBox?.onFocusChange = { hasFocus ->
            if (hasFocus) {
                hideKeyboard()
                chatInputBox?.setAddOptionsVisible(false)
                chatAddOptions?.setVisible(false)
            }
        }

        chatAddOptions?.onCameraClick = {
            if (checkCameraPermission()) {
                launchCamera()
            } else {
                cameraPermissionLauncher.launch(Manifest.permission.CAMERA)
            }
        }

        chatAddOptions?.onPhotoAlbumClick = {
            pickImageLauncher.launch("image/*")
        }

        chatAddOptions?.onFileClick = {
            pickFileLauncher.launch(arrayOf("image/*", "application/pdf", "application/msword", "application/vnd.openxmlformats-officedocument.wordprocessingml.document", "text/plain"))
        }

        chatInputBox?.onSendClick = { message, _ ->
            viewModel.sendMessage(message)
            hideKeyboard()
            chatInputBox?.clearInput()
        }
    }

    private fun observeState() {
        viewLifecycleOwner.lifecycleScope.launch {
            viewLifecycleOwner.repeatOnLifecycle(Lifecycle.State.STARTED) {
                viewModel.uiState.collect { state ->
                    adapter?.submitList(state.messages) {
                        if (state.messages.isNotEmpty()) {
                            recyclerView?.scrollToPosition(state.messages.size - 1)
                        }
                    }
                    if (state.sessionName != null) {
                        toolbar?.setTitle(state.sessionName)
                    }
                    state.error?.let { error ->
                        Toast.makeText(context, error, Toast.LENGTH_SHORT).show()
                        viewModel.clearError()
                    }
                }
            }
        }
    }

    private fun hideKeyboard() {
        val imm = requireContext().getSystemService(Context.INPUT_METHOD_SERVICE) as InputMethodManager
        imm.hideSoftInputFromWindow(view?.windowToken, 0)
    }

    private fun launchCamera() {
        val uri = createImageUri()
        tempCameraUri = uri
        takePictureLauncher.launch(uri)
    }

    private fun createImageUri(): Uri {
        val contentValues = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, "IMG_${System.currentTimeMillis()}.jpg")
            put(MediaStore.MediaColumns.MIME_TYPE, "image/jpeg")
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                put(MediaStore.MediaColumns.RELATIVE_PATH, "Pictures/DoDroidAI")
            }
        }
        return requireContext().contentResolver.insert(
            MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
            contentValues
        ) ?: throw IllegalStateException("Failed to create image URI")
    }

    private fun addImageAttachment(uri: Uri) {
        addAttachment(uri)
    }

    private fun addAttachment(uri: Uri) {
        val mimeType = requireContext().contentResolver.getType(uri) ?: "application/octet-stream"
        if (!isSupportedMimeType(mimeType)) {
            Toast.makeText(context, R.string.file_format_unsupported, Toast.LENGTH_SHORT).show()
            return
        }
        val fileName = getFileName(uri)
        val size = getFileSize(uri)
        val item = AttachmentItem(uri, fileName, size, mimeType)
        chatInputBox?.addAttachment(item)
    }

    private fun isSupportedMimeType(mimeType: String): Boolean {
        val supportedTypes = listOf(
            "image/", "application/pdf", "application/msword",
            "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
            "text/plain"
        )
        return supportedTypes.any { mimeType.startsWith(it) || mimeType == it }
    }

    private fun getFileName(uri: Uri): String {
        var name = "image"
        requireContext().contentResolver.query(uri, null, null, null, null)?.use { cursor ->
            val nameIndex = cursor.getColumnIndex(MediaStore.MediaColumns.DISPLAY_NAME)
            if (nameIndex >= 0 && cursor.moveToFirst()) {
                name = cursor.getString(nameIndex) ?: name
            }
        }
        return name
    }

    private fun getFileSize(uri: Uri): Long {
        var size = 0L
        requireContext().contentResolver.query(uri, null, null, null, null)?.use { cursor ->
            val sizeIndex = cursor.getColumnIndex(MediaStore.MediaColumns.SIZE)
            if (sizeIndex >= 0 && cursor.moveToFirst()) {
                size = cursor.getLong(sizeIndex)
            }
        }
        return size
    }

    private fun checkCameraPermission(): Boolean {
        return ContextCompat.checkSelfPermission(
            requireContext(),
            Manifest.permission.CAMERA
        ) == PackageManager.PERMISSION_GRANTED
    }

    companion object {
        private const val ARG_SESSION_ID = "session_id"

        fun newInstance(sessionId: String? = null): ChatFragment {
            return ChatFragment().apply {
                arguments = Bundle().apply {
                    putString(ARG_SESSION_ID, sessionId)
                }
            }
        }
    }
}