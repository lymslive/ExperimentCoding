#ifndef CVECTOR_H__
#define CVECTOR_H__

// 有序的序列容器
// 内部维护两个 vector, 一个按原始顺序填充内存，另一个保护已排序的指针
// 适用于初始化后不再增删的集合，比 map 省内存
// 也适用于需要保持两种顺序的集合
template <class ValueT>
class CSortedVec
{
public:
	CSortedVec() : m_pveSorted(NULL) {}
	~CSortedVec();

	typedef bool ValueCmpFun(const ValueT& a, const ValueT& b);
	void sort(ValueCmpFun = NULL);
	bool sorted() const { return m_vecSorted.size() > 0 && m_vecSorted.size() == m_vecOrigin.size(); }

	CSortedVec& add(const ValueT& val);

	bool exist(const ValueT& val) const;
	bool exist(const ValueT* pVal) const;

	size_t size() const { return m_vecOrigin.size(); }

	// 访问已排序的元素
	ValueT& operator[] (size_t idx);
	const ValueT& operator[] (size_t idx) const;
	// 访问未排序的元素
	ValueT& operator() (size_t idx);
	const ValueT& operator() (size_t idx) const;

	// 迭代器
	friend class Iterator;
	friend class ConstIterator;

	template <class ValueT> 
	class Iterator : public std::iterator<std::random_access_iterotor_tag, ValueT>
	{
	public:
		Iterator(const CSortedVec<ValueT>* pHost) : m_pHost(pHost) {}
		ValueT& operator* () { return *getptr(); }
		ValueT* operator-> () { return getptr(); }
		Iterator& operator++ ();
		Iterator& operator++ (int);
		Iterator& operator-- ();
		Iterator& operator-- (int);
		Iterator& operator+ (size_t diff);
		Iterator& operator- (size_t diff);
		Iterator& operator+= (size_t diff);
		Iterator& operator-= (size_t diff);
	protected:
		ValuteT* getptr();
		const CSortedVec<ValueT>* m_pHost;
		size_t m_idx;
	};

	template <class ValueT> 
	class ConstIterator : Iterator<ValueT>
	{
	public:
		ConstIterator(const CSortedVec<ValueT>* pHost) : Iterator(pHost) {}
		const ValueT& operator* () { return *(const_cast<const ValueT*>(getptr())); }
		const ValueT* operator-> () { return const_cast<const ValueT*>(getptr()); }
	};

	Iterator begin();
	Iterator end();
	const ConstIterator cbegin() const;
	const ConstIterator cend() const;

	// 原始指针迭代器
	ValueT* rbegin() { return &m_vecOrigin[0]; }
	ValueT* rend() { return rbegin() + m_vecOrigin.size(); }
	const ValueT* rbegin() const { return &m_vecOrigin[0]; }
	const ValueT* rend() const { return rbegin() + m_vecOrigin.size(); }

	ValueT** sbegin() { return &m_vecSorted[0]; }
	ValueT** send() { return sbegin() + m_vecSorted.size(); }
	const ValueT** sbegin() const { return &m_vecSorted[0]; }
	const ValueT** send() const { return sbegin() + m_vecSorted.size(); }
	// 用法示例 *((*pp)+1)

private:
	std::vector<ValueT> m_vecOrigin;
	std::vector<ValueT*> m_vecSorted;
};

#endif /* end of include guard: CVECTOR_H__ */
