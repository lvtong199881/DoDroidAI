package com.example.dodroidai.data

import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flow

/**
 * 数据仓库接口
 */
interface DataRepository {
    val data: Flow<List<String>>
}

/**
 * 默认数据仓库实现
 */
class DefaultDataRepository : DataRepository {
    override val data: Flow<List<String>> = flow { emit(listOf("Android")) }
}