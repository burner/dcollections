/*********************************************************
   Copyright: (C) 2008-2010 by Steven Schveighoffer.
              All rights reserved

   License: $(LICENSE)

**********************************************************/
module dcollections.Deque;

public import dcollections.model.List,
       dcollections.model.Keyed;

private import dcollections.DefaultFunctions;

version(unittest) private import std.traits;

/**
 * A Deque is similar to an array, but has O(1) amortized append and prepend
 * performance.  The constant factor is slightly larger than an array for
 * operations.
 */
class Deque(V) : Keyed!(size_t, V), List!V
{
    // implementation notes:  The _pre array contains all the elements
    // prepended, in reverse order.  The reason it's in reverse order is
    // because array appending is supported with O(1) performance.  _post
    // contains all the elements appended.
    private V[] _pre, _post;

    version(unittest)
    {
        enum doUnittest = isIntegral!V;

        static Deque create(V[] elems...)
        {
            // create the deque by prepending the first half of the elements,
            // then appending the second half.
            return (new Deque(elems[$/2..$])).prepend(elems[0..$/2]);
        }
    }
    else enum doUnittest = false;

    /**
     * The cursor type, used to refer to individual elements
     */
    struct cursor
    {
        // note, when _pre is set, ptr actually points to the end of the
        // element (i.e. next element in memory).  This is to prevent the
        // pointer from pointing outside the memory block.
        private V *ptr;
        private bool _pre = false;
        private bool _empty = false;

        /**
         * get the value pointed to
         */
        @property V front()
        {
            assert(!_empty, "Attempting to read the value of an empty cursor of " ~ Deque.stringof);
            return _pre ? *(ptr-1) : *ptr;
        }
        
        /**
         * set the value pointed to
         */
        @property V front(V v)
        {
            assert(!_empty, "Attempting to write the value of an empty cursor of " ~ Deque.stringof);
            return (_pre ? *(ptr-1) : *ptr) = v;
        }

        /**
         * pop the front of the cursor.  This only is valid if the cursor is
         * not empty.  Normally you do not use this, but it allows the cursor
         * to be considered a range, convenient for passing to range-accepting
         * functions.
         */
        void popFront()
        {
            assert(!_empty, "Attempting to popFront() an empty cursor of " ~ Deque.stringof);
            if(_pre)
                --ptr;
            else
                ++ptr;
            _empty = true;
        }

        /**
         * returns true if this cursor does not point to a valid element.
         */
        @property bool empty()
        {
            return _empty;
        }

        /**
         * Length is trivial to add, allows cursors to be used in more
         * algorithms.
         */
        @property size_t length()
        {
            return _empty ? 0 : 1;
        }

        /**
         * opIndex costs nothing, and it allows more algorithms to accept
         * cursors.
         */
        @property V opIndex(size_t idx)
        {
            assert(idx < length, "Attempt to access invalid index on cursor of type " ~ Deque.stringof);
            return front;
        }

        /**
         * Save property needed to satisfy forwardRange requirements.
         */
        @property cursor save()
        {
            return this;
        }

        /**
         * compare two cursors for equality.  Note that only the position of
         * the cursor is checked, whether it's empty or not is not checked.
         *
         * also note that it's possible for two cursors to compare not equal
         * even though they point to the same element.  This situation is
         * caused by the implementation of Deque.  However, it can only happen
         * if one uses popFront.
         */
        bool opEquals(ref const(cursor) it) const
        {
            return it.ptr is ptr;
        }
    }

    /**
     * a random-access range for the Deque.
     */
    struct range
    {
        // a range that combines both the pre and post ranges.
        private V[] _pre, _post;

        /**
         * Get/set the first element in the range.  Illegal to call this on an
         * empty range.
         */
        @property ref V front()
        {
            return _pre.length ? _pre[$-1] : _post[0];
        }

        /**
         * Get/set the last element in the range.  Illegal to call this on an
         * empty range.
         */
        @property ref V back()
        {
            return _post.length ? _post[$-1] : _pre[0];
        }

        /**
         * Pop the first element from the front of the range.
         */
        void popFront()
        {
            if(_pre.length)
                _pre = _pre[0..$-1];
            else
                _post = _post[1..$];
        }

        /**
         * Pop the last element from the back of the range.
         */
        void popBack()
        {
            if(_post.length)
                _post = _post[0..$-1];
            else
                _pre = _pre[1..$];
        }

        /**
         * Get the item at the given index.
         */
        ref V opIndex(size_t key)
        {
            if(_pre.length > key)
                return _pre[$-1-key];
            else
                return _post[key - _pre.length];
        }

        /**
         * Slice a range according to two indexes.  This is required for random
         * access ranges.
         */
        range opSlice(size_t low, size_t hi)
        {
            assert(low <= hi, "invalid parameters used to slice " ~ Deque.stringof);
            range result;
            if(low < _pre.length)
            {
                if(hi < _pre.length)
                    result._pre = _pre[$-hi..$-low];
                else
                {
                    result._pre = _pre[0..$-low];
                    result._post = _post[0..hi-_pre.length];
                }
            }
            else
            {
                result._post = _post[low-_pre.length..hi-_pre.length];
            }
            return result;
        }

        /**
         * The length of the range.
         */
        @property size_t length()
        {
            return _pre.length + _post.length;
        } 

        /**
         * Does this range contain any elements?
         */
        @property bool empty()
        {
            return length == 0;
        }

        /**
         * Required save function to satisfy isForwardRange
         */
        @property range save()
        {
            return this;
        }

        /**
         * Get a cursor that points to the beginning of this range.
         */
        @property cursor begin()
        {
            cursor result;
            result._pre = _pre.length ? true : false;
            result.ptr = result._pre ? _pre.ptr + _pre.length : _post.ptr;
            result._empty = (length == 0);
            return result;
        }

        /**
         * Get a cursor that points to the end of this range.
         */
        @property cursor end()
        {
            cursor result;
            result.ptr = _post.ptr + _post.length;
            result._empty = true;
            return result;
        }
    }

    /**
     * Use an array as the backing storage.  This does not duplicate the array.
     * Use new Deque(storage.dup) to make a distinct copy.
     */
    this(V[] storage...)
    {
        _post = storage;
    }

    /**
     * Constructor that uses the given iterator to get the initial elements.
     */
    this(Iterator!V initialElements)
    {
        add(initialElements);
    }

    static if(doUnittest) unittest
    {
        auto dq = create(1, 2, 3, 4, 5);
        auto dq2 = new Deque(dq);
        assert(dq == dq2);
        dq[0] = 2;
        assert(dq != dq2);
    }

    /**
     * clear the container of all values.  Note that unlike arrays, it is no
     * longer safe to use elements that were in the array list.  This is
     * consistent with the other container types.
     */
    Deque clear()
    {
        _pre.length = _post.length = 0;
        _pre.assumeSafeAppend();
        _post.assumeSafeAppend();
        return this;
    }

    /**
     * return the number of elements in the collection
     */
    @property size_t length() const
    {
        return _pre.length + _post.length;
    }

    /**
     * return a cursor that points to the first element in the list.
     */
    @property cursor begin()
    {
        return this[].begin;
    }

    /**
     * return a cursor that points to just beyond the last element in the
     * list.  The cursor will be empty, so you cannot call front on it.
     */
    @property cursor end()
    {
        return this[].end;
    }

    private int _apply(scope int delegate(ref bool, ref size_t, ref V) dg, range r)
    {
        int dgret;

        // do the _pre array
        auto _prelength = _pre.length; // needed for _post iteration
        if(r._pre.length)
        {
            auto i = r._pre.ptr + r._pre.length - 1;
            auto nextGood = i;
            auto last = r._pre.ptr - 1;
            auto endref = _pre.ptr - 1;

            bool doRemove;

            //
            // loop before removal
            //
            for(; dgret == 0 && i != last; --i, --nextGood)
            {
                doRemove = false;
                size_t key = _pre.ptr + _pre.length - i - 1;
                if((dgret = dg(doRemove, key, *i)) == 0)
                {
                    if(doRemove)
                    {
                        //
                        // first removal
                        //
                        --i;
                        break;
                    }
                }
            }

            //
            // loop after first removal
            //
            if(nextGood != i)
            {
                for(; i != endref; --i, --nextGood)
                {
                    doRemove = false;
                    size_t key = _pre.ptr + _pre.length - i - 1;
                    if(i <= last || dgret != 0 || (dgret = dg(doRemove, key, *i)) != 0 || !doRemove)
                    {
                        //
                        // either not calling dg any more or doRemove was
                        // false.
                        //
                        *nextGood = *i;
                    }
                    else
                    {
                        //
                        // dg requested a removal
                        //
                        ++nextGood;
                    }
                }
                //
                // shorten the length
                //
                // TODO: we know we are always shrinking.  So we should probably
                // set the length value directly rather than calling the runtime
                // function.
                _pre = _pre[nextGood - _pre.ptr..$];
            }

        }
        if(r._post.length)
        {
            // run the same algorithm as in ArrayList.
            auto i = r._post.ptr;
            auto nextGood = i;
            auto last = r._post.ptr + r._post.length;
            auto endref = _post.ptr + _post.length;

            bool doRemove;

            //
            // loop before removal
            //
            for(; dgret == 0 && i != last; ++i, ++nextGood)
            {
                doRemove = false;
                size_t key = i - _post.ptr + _prelength;
                if((dgret = dg(doRemove, key, *i)) == 0)
                {
                    if(doRemove)
                    {
                        //
                        // first removal
                        //
                        ++i;
                        break;
                    }
                }
            }

            //
            // loop after first removal
            //
            if(nextGood != i)
            {
                for(; i != endref; ++i, ++nextGood)
                {
                    doRemove = false;
                    size_t key = i - _post.ptr + _prelength;
                    if(i >= last || dgret != 0 || (dgret = dg(doRemove, key, *i)) != 0 || !doRemove)
                    {
                        //
                        // either not calling dg any more or doRemove was
                        // false.
                        //
                        *nextGood = *i;
                    }
                    else
                    {
                        //
                        // dg requested a removal
                        //
                        --nextGood;
                    }
                }
                //
                // shorten the length
                //
                // TODO: we know we are always shrinking.  So we should probably
                // set the length value directly rather than calling the runtime
                // function.
                _post.length = nextGood - _post.ptr;
                _post.assumeSafeAppend();
            }
        }
        return dgret;
    }

    private int _apply(scope int delegate(ref bool, ref V) dg, range r)
    {
        int _dg(ref bool b, ref size_t k, ref V v)
        {
            return dg(b, v);
        }
        return _apply(&_dg, r);
    }

    /**
     * Iterate over the elements in the Deque, telling it which ones
     * should be removed
     *
     * Use like this:
     *
     * -------------
     * // remove all odd elements
     * foreach(ref doRemove, v; &deque.purge)
     * {
     *   doRemove = (v & 1) != 0;
     * }
     * ------------
     */
    int purge(scope int delegate(ref bool doRemove, ref V value) dg)
    {
        return _apply(dg, this[]);
    }

    static if(doUnittest) unittest
    {
        auto dq = create(0,1,2,3,4);
        foreach(ref p, i; &dq.purge)
        {
            p = (i & 1);
        }

        assert(dq == cast(V[])[0, 2, 4]);
    }

    /**
     * Iterate over the keys and elements in the Deque, telling it which ones
     * should be removed.
     *
     * Use like this:
     * -------------
     * // remove all odd indexes
     * foreach(ref doRemove, k, v; &deque.purge)
     * {
     *   doRemove = (k & 1) != 0;
     * }
     * ------------
     */
    int keypurge(scope int delegate(ref bool doRemove, ref size_t key, ref V value) dg)
    {
        return _apply(dg, this[]);
    }

    static if(doUnittest) unittest
    {
        auto dq = create(1,2,3,4,5);
        size_t lastk = ~0;
        foreach(ref p, k, i; &dq.keypurge)
        {
            if(lastk != ~0)
                assert(lastk + 1 == k);
            lastk = k;
            p = (k & 1);
        }

        assert(dq == cast(V[])[1, 3, 5]);
    }

    /**
     * remove all the elements in the given range.  Returns a valid cursor that
     * points to the element just beyond the given range
     *
     * Runs in O(n) time.
     */
    cursor remove(range r)
    in
    {
        assert(belongs(r));
    }
    body
    {
        int check(ref bool b, ref V)
        {
            b = true;
            return 0;
        }
        _apply(&check, r);
        cursor result;
        if(r._post.length)
        {
            result.ptr = r._post.ptr;
            result._empty = (_post.ptr + _post.length > result.ptr);
        }
        else if(r._pre.ptr == _pre.ptr)
        {
            result.ptr = _post.ptr;
            result._empty = (_post.length > 0);
        }
        else
        {
            // ptr will be in pre
            result.ptr = r._pre.ptr;
            result._pre = true;
        }
               
        return result;
    }

    static if(doUnittest) unittest
    {
        auto dq = create(1, 2, 3, 4, 5);
        dq.remove(dq[1..4]);
        assert(dq == cast(V[])[1, 5]);
    }

    /**
     * remove the element pointed to by elem.  Returns a cursor to the element
     * just beyond this one.
     *
     * Runs in O(n) time
     */
    cursor remove(cursor elem)
    in
    {
        assert(belongs(elem));
    }
    body
    {
        if(elem._empty)
        {
            // nothing to remove, but we want to get the next element.
            if(elem._pre)
            {
                if(elem.ptr is _pre.ptr)
                {
                    elem.ptr = _post.ptr;
                    elem._empty = _post.length > 0;
                    elem._pre = false;
                }
                else
                    elem._empty = false;
            }
            else
            {
                elem._empty = (_post.ptr + _post.length == elem.ptr);
            }
            return elem;
        }
        else
        {
            range r;
            if(elem._pre)
                r._pre = (elem.ptr-1)[0..1];
            else
                r._post = elem.ptr[0..1];
            return remove(r);
        }
    }

    static if(doUnittest) unittest
    {
        auto dq = create(1, 2, 3, 4, 5);
        dq.remove(dq.elemAt(2));
        assert(dq == cast(V[])[1, 2, 4, 5]);
    }

    /**
     * get a cursor at the given index
     */
    cursor elemAt(size_t idx)
    in
    {
        assert(idx < length);
    }
    body
    {
        cursor it;
        if(idx < _pre.length)
        {
            it._pre = true;
            it.ptr = _pre.ptr + (_pre.length - idx);
        }
        else
        {
            it.ptr = _post.ptr + (idx - _pre.length);
        }
        return it;
    }

    static if(doUnittest) unittest
    {
        auto dq = create(1,2,3,4,5);
        foreach(i; 0..dq.length)
        {
            auto cu = dq.elemAt(i);
            assert(!cu.empty);
            assert(cu.front == i + 1);
        }
    }

    /**
     * get the value at the given index.
     */
    V opIndex(size_t key)
    {
        return elemAt(key).front;
    }

    /**
     * set the value at the given index.
     */
    V opIndexAssign(V value, size_t key)
    {
        return elemAt(key).front = value;
    }

    /**
     * set the value at the given index
     */
    Deque set(size_t key, V value, out bool wasAdded)
    {
        this[key] = value;
        wasAdded = false;
        return this;
    }

    /**
     * set the value at the given index
     */
    Deque set(size_t key, V value)
    {
        this[key] = value;
        return this;
    }

    static if(doUnittest) unittest
    {
        auto dq = create(1, 2, 3, 4, 5);
        bool wasAdded = true;
        assert(dq.set(2, 8, wasAdded)[2] == 8);
        assert(!wasAdded);
        assert(dq.set(3, 10)[3] == 10);
        assert(dq == cast(V[])[1, 2, 8, 10, 5]);
    }

    /**
     * iterate over the collection
     */
    int opApply(scope int delegate(ref V value) dg)
    {
        int _dg(ref size_t, ref V value)
        {
            return dg(value);
        }
        return opApply(&_dg);
    }

    /**
     * iterate over the collection with key and value
     */
    int opApply(scope int delegate(ref size_t key, ref V value) dg)
    {
        int retval = 0;
        foreach(i; 0.._pre.length)
        {
            if((retval = dg(i, _pre[$-1-i])) != 0)
                break;
        }
        foreach(i; 0.._post.length)
        {
            size_t key = _pre.length + i;
            if((retval = dg(key, _post[i])) != 0)
                break;
        }
        return retval;
    }

    static if(doUnittest) unittest
    {
        auto dq = create(1, 2, 3, 4, 5);
        size_t idx = 0;
        foreach(i; dq)
        {
            assert(i == dq[idx++]);
        }
        assert(idx == dq.length);
        idx = 0;
        foreach(k, i; dq)
        {
            assert(idx == k);
            assert(i == idx + 1);
            assert(i == dq[idx++]);
        }
        assert(idx == dq.length);
    }

    /**
     * returns true if the given index is valid
     *
     * Runs in O(1) time
     */
    bool containsKey(size_t key)
    {
        return key < length;
    }

    /**
     * add the given value to the end of the list.  Always returns true.
     */
    Deque add(V v, out bool wasAdded)
    {
        //
        // append to this array.
        //
        _post ~= v;
        wasAdded = true;
        return this;
    }

    /**
     * add the given value to the end of the list.
     */
    Deque add(V v)
    {
        bool ignored;
        return add(v, ignored);
    }

    /**
     * adds all elements from the given iterator to the end of the list.
     */
    Deque add(Iterator!(V) coll)
    {
        size_t ignored;
        return add(coll, ignored);
    }

    /**
     * adds all elements from the given iterator to the end of the list.
     */
    Deque add(Iterator!(V) coll, out uint numAdded)
    {
        //
        // generic case
        //
        numAdded = coll.length;
        if(numAdded != NO_LENGTH_SUPPORT)
        {
            if(numAdded > 0)
            {
                int i = _post.length;
                _post.length += numAdded;
                foreach(v; coll)
                    _post [i++] = v;
            }
        }
        else
        {
            auto origlength = _post.length;
            foreach(v; coll)
                _post ~= v;
            numAdded = _post.length - origlength;
        }
        return this;
    }


    /**
     * appends the array to the end of the list
     */
    Deque add(V[] array)
    {
        uint ignored;
        return add(array, ignored);
    }

    /**
     * appends the array to the end of the list
     */
    Deque add(V[] array, out uint numAdded)
    {
        numAdded = array.length;
        if(array.length)
        {
            _post ~= array;
        }
        return this;
    }

    static if(doUnittest) unittest
    {
        // add single element
        bool wasAdded = false;
        auto dq = new Deque;
        dq.add(1);
        dq.add(2, wasAdded);
        assert(dq.length == 2);
        assert(dq == cast(V[])[1, 2]);
        assert(wasAdded);

        // add other collection
        uint numAdded = 0;
        dq.add(dq, numAdded);
        dq.add(dq);
        assert(dq == cast(V[])[1, 2, 1, 2, 1, 2, 1, 2]);
        assert(numAdded == 2);

        // add array
        dq.clear();
        dq.add(cast(V[])[1, 2, 3, 4, 5]);
        dq.add(cast(V[])[1, 2, 3, 4, 5], numAdded);
        assert(dq == cast(V[])[1, 2, 3, 4, 5, 1, 2, 3, 4, 5]);
        assert(numAdded == 5);
    }

    // Deque specific functions
    Deque prepend(V value, out bool wasAdded)
    {
        _pre ~= value;
        wasAdded = true;
        return this;
    }

    Deque prepend(V value)
    {
        bool dummy = void;
        return prepend(value, dummy);
    }

    Deque prepend(Iterator!V values, out size_t numAdded)
    {
        // append to pre, then reverse that portion of the array
        auto len = values.length;
        if(len != NO_LENGTH_SUPPORT)
        {
            _pre.length += len;
            auto ptr = _pre.ptr + _pre.length-1;
            foreach(v; values)
                *ptr-- = v;
            numAdded = len;
        }
        else
        {
            // prepend them in reverse order, then reverse the portion added.
            len = _pre.length;
            foreach(v; values)
                _pre ~= v;
            _pre[len..$].reverse;
            numAdded =  _pre.length - len;
        }
        return this;
    }

    Deque prepend(Iterator!V values)
    {
        size_t dummy = void;
        return prepend(values, dummy);
    }

    Deque prepend(V[] values)
    {
        if(values.length)
        {
            _pre.length += values.length;
            auto ptr = _pre.ptr + _pre.length-1;
            foreach(v; values)
                *ptr-- = v;
        }
        return this;
    }


    /**
     * returns a concatenation of the array list and another list.
     */
    Deque concat(List!(V) rhs)
    {
        return dup().add(rhs);
    }

    /**
     * returns a concatenation of the array list and an array.
     */
    Deque concat(V[] array)
    {
        auto retval = new Deque();
        retval._pre = _pre.dup;
        retval._post = _post ~ array;
        return retval;
    }

    /**
     * returns a concatenation of the array list and an array.
     */
    Deque concat_r(V[] array)
    {
        auto retval = dup();

        retval.prepend(array);
        return retval;
    }

    version(testcompiler)
    {
    }
    else
    {
        // workaround for compiler deficiencies
        alias concat opCat;
        alias concat_r opCat_r;
        alias add opCatAssign;
    }

    static if(doUnittest) unittest
    {
        auto dq = create(1, 2, 3, 4, 5);
        auto dq2 = dq.concat(dq);
        assert(dq2 !is dq);
        assert(dq2 == cast(V[])[1, 2, 3, 4, 5, 1, 2, 3, 4, 5]);
        assert(dq == cast(V[])[1, 2, 3, 4, 5]);

        dq2 = dq.concat(cast(V[])[6, 7, 8, 9, 10]);
        assert(dq2 !is dq);
        assert(dq2 == cast(V[])[1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
        assert(dq == cast(V[])[1, 2, 3, 4, 5]);

        dq2 = dq.concat_r(cast(V[])[6, 7, 8, 9, 10]);
        assert(dq2 !is dq);
        assert(dq2 == cast(V[])[6, 7, 8, 9, 10, 1, 2, 3, 4, 5]);
        assert(dq == cast(V[])[1, 2, 3, 4, 5]);

        dq2 = dq ~ dq;
        assert(dq2 !is dq);
        assert(dq2 == cast(V[])[1, 2, 3, 4, 5, 1, 2, 3, 4, 5]);
        assert(dq == cast(V[])[1, 2, 3, 4, 5]);

        dq2 = dq ~ cast(V[])[6, 7, 8, 9, 10];
        assert(dq2 !is dq);
        assert(dq2 == cast(V[])[1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
        assert(dq == cast(V[])[1, 2, 3, 4, 5]);

        dq2 = cast(V[])[6, 7, 8, 9, 10] ~ dq;
        assert(dq2 !is dq);
        assert(dq2 == cast(V[])[6, 7, 8, 9, 10, 1, 2, 3, 4, 5]);
        assert(dq == cast(V[])[1, 2, 3, 4, 5]);
    }

    /**
     * Returns a slice of an array list.
     *
     * The returned slice begins at index b and ends at, but does not include,
     * index e.
     */
    range opSlice(size_t b, size_t e)
    {
        assert(b <= length && e <= length);
        range result;
        immutable prelen = _pre.length;
        if(b < prelen)
        {
            if(e < prelen)
            {
                result._pre = _pre[prelen-e..prelen-b];
            }
            else
            {
                result._pre = _pre[0..prelen-b];
                result._post = _post[0..e-prelen];
            }
        }
        else
        {
            result._post = _post[b-prelen..e-prelen];
        }
        return result;
    }

    /**
     * Slice an array given the cursors
     */
    range opSlice(cursor b, cursor e)
    {
        // Convert b and e to indexes, then use the index function to do the
        // hard work.
        return opSlice(indexOf(b), indexOf(e));
    }

    /**
     * get the array that this array represents.  This is NOT a copy of the
     * data, so modifying elements of this array will modify elements of the
     * original Deque.  Appending elements from this array will not affect
     * the original array list just like appending to an array will not affect
     * the original.
     */
    range opSlice()
    {
        range result;
        result._pre = _pre;
        result._post = _post;
        return result;
    }

    static if(doUnittest) unittest
    {
        pragma(msg, "Deque No unittest here yet " ~ __LINE__.stringof);
    }

    /**
     * Returns a copy of an array list
     */
    Deque dup()
    {
        auto result = new Deque();
        result._pre = _pre.dup;
        result._post = _post.dup;
        return result;
    }

    static if(doUnittest) unittest
    {
        auto dq = new Deque;
        dq.add(2);
        dq.prepend(1);
        auto dq2 = dq.dup;
        assert(dq._pre !is dq2._pre);
        assert(dq._post !is dq2._post);
        assert(dq == dq2);
        dq[0] = 0;
        dq.add(3);
        assert(dq2 == cast(V[])[1, 2]);
        assert(dq == cast(V[])[0, 2, 3]);
    }

    /**
     * operator to compare two objects.
     *
     * If o is a List!(V), then this does a list compare.
     * If o is null or not an Deque, then the return value is 0.
     */
    override bool opEquals(Object o)
    {
        if(o !is null)
        {
            auto li = cast(List!(V))o;
            if(li !is null && li.length == length)
            {
                auto r = this[];
                foreach(elem; li)
                {
                    // NOTE this is a workaround for compiler bug 4088
                    static if(is(V == interface))
                    {
                        if(cast(Object)elem != cast(Object)r.front)
                            return false;
                    }
                    else
                    {
                        if(elem != r.front)
                            return false;
                    }
                    r.popFront();
                }

                //
                // equal
                //
                return true;
            }
        }
        //
        // no comparison possible.
        //
        return false;
    }

    static if(doUnittest) unittest
    {
        auto dq = new Deque;
        dq.add(cast(V[])[1, 2, 3, 4, 5]);
        assert(dq == dq.dup);
    }

    /**
     * Compare to a V array.
     *
     * equivalent to this[] == array.
     */
    bool opEquals(V[] array)
    {
        // short circuit to avoid running through algorithm.equal when lengths
        // aren't equivalent.
        if(length != array.length)
            return false;
        // this is to work around compiler bug 4088 and 4589
        static if(is(V == interface))
        {
            return std.algorithm.equal!"cast(Object)a == cast(Object)b"(this[], array);
        }
        else
        {
            return std.algorithm.equal(this[], array);
        }
    }

    /**
     *  Look at the element at the front of the Deque.
     *  TODO: this should be inout
     */
    @property V front()
    {
        return _pre.length ? _pre[$-1] : _post[0];
    }

    /**
     * Look at the element at the end of the Deque.
     * TODO: this should be inout
     */
    @property V back()
    {
        return _post.length ? _post[$-1] : _pre[0];
    }

    /**
     * Remove the element at the end of the Deque and return its value.
     */
    V take()
    {
        V retval = void;
        if(_post.length)
        {
            retval = _post[$-1];
            _post = _post[0..$-1];
            _post.assumeSafeAppend();
        }
        else
        {
            retval = _pre[0];
            _pre = _pre[1..$];
        }
        return retval;
    }

    static if(doUnittest) unittest
    {
        auto dq = new Deque;
        dq.add(cast(V[])[1, 2, 3, 4, 5]);
        assert(dq.take() == 5);
        assert(dq == cast(V[])[1, 2, 3, 4]);
    }

    /**
     * Get the index of a particular cursor.
     */
    size_t indexOf(cursor c)
    {
        assert(belongs(c));
        if(c._pre)
        {
            return _pre.length - (c.ptr - _pre.ptr);
        }
        else
        {
            return _pre.length + (c.ptr - _post.ptr);
        }
    }

    /**
     * returns true if the given cursor belongs points to an element that is
     * part of the container.  If the cursor is the same as the end cursor,
     * true is also returned.
     */
    bool belongs(cursor c)
    {
        if(c._pre)
        {
            // points beyond the pre array, not a valid cursor
            if(c.ptr == _pre.ptr && !c.empty)
                return false;
            return c.ptr >= _pre.ptr && c.ptr - _pre.ptr <= _pre.length;
        }
        else
        {
            auto lastpost = _post.ptr + _post.length;
            if(c.ptr == lastpost && !c.empty)
                // points beyond the post array, not a valid cursor
                return false;
            return c.ptr >= _post.ptr && c.ptr <= lastpost;
        }
    }

    bool belongs(range r)
    {
        // ensure that r's pre and post are fully enclosed by our pre and post
        if(r._pre.length > 0)
        {
            if(r._post.length > 0)
            {
                if(r._pre.ptr != _pre.ptr || r._post.ptr != _post.ptr)
                    // strange range with more or less data in the middle
                    return false;
                return r._pre.length <= _pre.length &&
                    r._post.length <= _post.length;
            }
            else
            {
                return r._pre.ptr >= _pre.ptr && r._pre.ptr + r._pre.length <= _pre.ptr + _pre.length;
            }
        }
        return r._post.ptr >= _post.ptr && r._post.ptr + r._post.length <= _post.ptr + _post.length;
    }

    static if(doUnittest) unittest
    {
        auto dq = new Deque;
        dq.add(cast(V[])[1, 2, 3, 4, 5]);
        auto cu = dq.elemAt(2);
        assert(cu.front == 3);
        assert(dq.belongs(cu));
        assert(dq.indexOf(cu) == 2);
        auto r = dq[0..2];
        assert(dq.belongs(r));
        assert(dq.indexOf(r.end) == 2);

        auto dq2 = dq.dup;
        assert(!dq2.belongs(cu));
        assert(!dq2.belongs(r));
    }

    /**
     * Sort according to a given comparison function
     */
    Deque sort(scope bool delegate(ref V v1, ref V v2) comp)
    {
        std.algorithm.sort!(comp)(this[]);
        return this;
    }

    /**
     * Sort according to a given comparison function
     */
    Deque sort(bool function(ref V v1, ref V v2) comp)
    {
        std.algorithm.sort!(comp)(this[]);
        return this;
    }

    /**
     * Sort according to the default comparison routine for V
     */
    Deque sort()
    {
        std.algorithm.sort!(DefaultLess!(V))(this[]);
        return this;
    }

    /**
     * Sort the list according to the given compare functor.  This is
     * a templatized version, and so can be used with functors, and might be
     * inlined.
     *
     * TODO: this should be called sort
     * TODO: if bug 3051 is resolved, then this can probably be
     * sortX(alias less)()
     * instead.
     */
    Deque sortX(T)(T less)
    {
        std.algorithm.sort!less(this[]);
        return this;
    }

    static if(doUnittest) unittest
    {
        auto dq = new Deque;
        dq.add(cast(V[])[1, 3, 5, 6, 4, 2]);
        dq.sort();
        assert(dq == cast(V[])[1, 2, 3, 4, 5, 6]);
        dq.sort(delegate bool (ref V a, ref V b) { return b < a; });
        assert(dq == cast(V[])[6, 5, 4, 3, 2, 1]);
        dq.sort(function bool (ref V a, ref V b) { if((a ^ b) & 1) return cast(bool)(a & 1); return a < b; });
        assert(dq == cast(V[])[1, 3, 5, 2, 4, 6]);

        struct X
        {
            V pivot;
            // if a and b are on both sides of pivot, sort normally, otherwise,
            // values >= pivot are treated less than values < pivot.
            bool opCall(V a, V b)
            {
                if(a < pivot)
                {
                    if(b < pivot)
                    {
                        return a < b;
                    }
                    return false;
                }
                else if(b >= pivot)
                {
                    return a < b;
                }
                return true;
            }
        }

        X x;
        x.pivot = 4;
        dq.sortX(x);
        assert(dq == cast(V[])[4, 5, 6, 1, 2, 3]);
    }
}

unittest
{
    // declare the array list types that should be unit tested.
    Deque!ubyte  dq1;
    Deque!byte   dq2;
    Deque!ushort dq3;
    Deque!short  dq4;
    Deque!uint   dq5;
    Deque!int    dq6;
    Deque!ulong  dq7;
    Deque!long   dq8;

    // ensure that reference types can be used
    Deque!(uint*) dq9;
    interface I {}
    class C : I {}
    Deque!C dq10;
    Deque!I dq11;
}
