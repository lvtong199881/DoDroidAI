package com.example.dodroidai.data.repository

import android.content.Context
import com.example.dodroidai.data.local.AppDatabase
import com.example.dodroidai.data.local.NoteEntity
import kotlinx.coroutines.flow.Flow

class NoteRepository(context: Context) {

    private val dao = AppDatabase.get(context).noteDao()

    fun observeNotes(): Flow<List<NoteEntity>> = dao.observeAll()

    fun search(query: String): Flow<List<NoteEntity>> = dao.search(query)

    suspend fun add(title: String, content: String): Long =
        dao.insert(
            NoteEntity(
                title = title.trim(),
                content = content.trim()
            )
        )

    suspend fun delete(note: NoteEntity) = dao.delete(note)
}
