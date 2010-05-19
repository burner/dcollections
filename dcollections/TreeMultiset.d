/*********************************************************
   Copyright: (C) 2008 by Steven Schveighoffer.
              All rights reserved

   License: $(LICENSE)

**********************************************************/
module dcollections.TreeMultiset;

public import dcollections.model.Multiset;
public import dcollections.DefaultFunctions;

private import dcollections.RBTree;

version(unittest)
{
    import std.traits;
    import std.array;
    import std.range;
    static import std.algorithm;
}

/**
 * Implementation of the Multiset interface using Red-Black trees.  this
 * allows for O(lg(n)) insertion, removal, and lookup times.  It also creates
 * a sorted set of elements.  V must be comparable.
 *
 * Adding an element does not invalidate any cursors.
 *
 * Removing an element only invalidates the cursors that were pointing at
 * that element.
 *
 * You can replace the Tree implementation with a custom implementation, the
 * implementation must be a struct template which can be instantiated with a
 * single template argument V, and must implement the following members
 * (non-function members can be properties unless otherwise specified):
 *
 * parameters -> must be a struct with at least the following members:
 *   compareFunction -> the compare function to use (should be a
 *                      CompareFunction!(V))
 * 
 * void setup(parameters p) -> initializes the tree with the given parameters.
 *
 * uint count -> count of the elements in the tree
 *
 * node -> must be a struct/class with the following members:
 *   V value -> the value which is pointed to by this position (cannot be a
 *                property)
 *   node next -> the next node in the tree as defined by the compare
 *                function, or end if no other nodes exist.
 *   node prev -> the previous node in the tree as defined by the compare
 *                function.
 *
 * bool add(V v) -> add the given value to the tree according to the order
 * defined by the compare function.  If the element already exists in the
 * tree, the function should add it after all equivalent elements.
 *
 * node begin -> must be a node that points to the very first valid
 * element in the tree, or end if no elements exist.
 *
 * node end -> must be a node that points to just past the very last
 * valid element.
 *
 * node find(V v) -> returns a node that points to the first element in the
 * tree that contains v, or end if the element doesn't exist.
 *
 * node remove(node p) -> removes the given element from the tree,
 * returns the next valid element or end if p was last in the tree.
 *
 * void clear() -> removes all elements from the tree, sets count to 0.
 *
 * uint countAll(V v) -> returns the number of elements with the given value.
 *
 * node removeAll(V v) -> removes all the given values from the tree.
 */
class TreeMultiset(V, alias ImplTemp = RBDupTree, alias compareFunction=DefaultCompare) : Multiset!(V)
{
    version(unittest)
    {
        private enum doUnittest = isIntegral!V;

        bool arrayEqual(V[] arr)
        {
            if(length == arr.length)
            {
                uint[V] cnt;
                foreach(v; arr)
                    cnt[v]++;

                foreach(v; this)
                {
                    auto x = v in cnt;
                    if(!x || *x == 0)
                        return false;
                    --(*x);
                }
                return true;
            }
            return false;
        }
    }
    else
    {
        private enum doUnittest = false;
    }

    /**
     * convenience alias
     */
    alias ImplTemp!(V, compareFunction) Impl;

    private Impl _tree;

    /**
     * A cursor for elements in the tree
     */
    struct cursor
    {
        private Impl.Node ptr;
        private bool _empty = false;

        /**
         * get the value in this element
         */
        @property V front()
        {
            assert(!_empty, "Attempting to read the value of an empty cursor of " ~ TreeMultiset.stringof);
            return ptr.value;
        }

        /**
         * Tell if this cursor is empty (doesn't point to any value)
         */
        @property bool empty() const
        {
            return _empty;
        }

        /**
         * Move to the next element.
         */
        void popFront()
        {
            assert(!_empty, "Attempting to popFront() an empty cursor of " ~ TreeMultiset.stringof);
            _empty = true;
            ptr = ptr.next;
        }

        /**
         * compare two cursors for equality
         */
        bool opEquals(ref const cursor it) const
        {
            return it.ptr is ptr;
        }

        /**
         * TODO: uncomment when compiler is sane
         * compare two cursors for equality
         */
        /*bool opEquals(const cursor it) const
        {
            return it.ptr is ptr;
        }*/
    }

    static if(doUnittest) unittest
    {
        
        auto tms = new TreeMultiset;
        tms.add([1, 2, 2, 3, 3, 4, 5]);
        auto cu = tms.elemAt(3);
        assert(!cu.empty);
        assert(cu.front == 3);
        cu.popFront();
        assert(cu.empty);
        assert(tms.arrayEqual([1, 2, 2, 3, 3, 4, 5]));
    }


    /**
     * A range that can be used to iterate over the elements in the tree.
     */
    struct range
    {
        private Impl.Node _begin;
        private Impl.Node _end;

        /**
         * is the range empty?
         */
        @property bool empty()
        {
            return _begin is _end;
        }

        /**
         * Get a cursor to the first element in the range
         */
        @property cursor begin()
        {
            cursor c;
            c.ptr = _begin;
            c._empty = empty;
            return c;
        }

        /**
         * Get a cursor to the end element in the range
         */
        @property cursor end()
        {
            cursor c;
            c.ptr = _end;
            c._empty = true;
            return c;
        }

        /**
         * Get the first value in the range
         */
        @property V front()
        {
            assert(!empty, "Attempting to read front of an empty range cursor of " ~ TreeMultiset.stringof);
            return _begin.value;
        }

        /**
         * Get the last value in the range
         */
        @property V back()
        {
            assert(!empty, "Attempting to read the back of an empty range of " ~ TreeMultiset.stringof);
            return _end.prev.value;
        }

        /**
         * Move the front of the range ahead one element
         */
        void popFront()
        {
            assert(!empty, "Attempting to popFront() an empty range of " ~ TreeMultiset.stringof);
            _begin = _begin.next;
        }

        /**
         * Move the back of the range to the previous element
         */
        void popBack()
        {
            assert(!empty, "Attempting to popBack() an empty range of " ~ TreeMultiset.stringof);
            _end = _end.prev;
        }
    }

    static if(doUnittest) unittest
    {
        auto tms = new TreeMultiset;
        tms.add([1, 2, 2, 3, 3, 4, 5]);
        auto r = tms[];
        assert(std.algorithm.equal(r, cast(V[])[1, 2, 2, 3, 3, 4, 5]));
        assert(r.front == tms.begin.front);
        assert(r.back != r.front);
        auto oldfront = r.front;
        auto oldback = r.back;
        r.popFront();
        r.popFront();
        r.popBack();
        r.popBack();
        assert(r.front != r.back);
        assert(r.front != oldfront);
        assert(r.back != oldback);

        auto b = r.begin;
        assert(!b.empty);
        assert(b.front == r.front);
        auto e = r.end;
        assert(e.empty);
    }

    /**
     * Determine if a cursor belongs to the collection
     */
    bool belongs(cursor c)
    {
        // rely on the implementation to tell us
        return _tree.belongs(c.ptr);
    }

    /**
     * Determine if a range belongs to the collection
     */
    bool belongs(range r)
    {
        return _tree.belongs(r._begin) && (r.empty || _tree.belongs(r._end));
    }

    static if(doUnittest) unittest
    {
        auto tms = new TreeMultiset;
        tms.add([1, 2, 2, 3, 3, 4, 5]);
        auto cu = tms.elemAt(3);
        assert(cu.front == 3);
        assert(tms.belongs(cu));
        auto r = tms[tms.begin..cu];
        assert(tms.belongs(r));

        auto hs2 = tms.dup;
        assert(!hs2.belongs(cu));
        assert(!hs2.belongs(r));
    }

    /**
     * Iterate through the elements of the collection, specifying which ones
     * should be removed.
     *
     * Use like this:
     * -------------
     * // remove all odd elements
     * foreach(ref doPurge, v; &treeMultiset.purge)
     * {
     *   doPurge = ((v % 1) == 1);
     * }
     * -------------
     */
    final int purge(scope int delegate(ref bool doPurge, ref V v) dg)
    {
        auto it = _tree.begin;
        bool doPurge;
        int dgret = 0;
        auto _end = _tree.end; // cache end so it isn't always being generated
        while(it !is _end)
        {
            //
            // don't allow user to change value
            //
            V tmpvalue = it.value;
            doPurge = false;
            if((dgret = dg(doPurge, tmpvalue)) != 0)
                break;
            if(doPurge)
                it = _tree.remove(it);
            else
                it = it.next;
        }
        return dgret;
    }

    static if(doUnittest) unittest
    {
        auto tms = new TreeMultiset;
        tms.add([0, 1, 2, 2, 3, 3, 4]);
        foreach(ref p, i; &tms.purge)
        {
            p = (i & 1);
        }

        assert(tms.arrayEqual([0, 2, 2, 4]));
    }

    /**
     * iterate over the collection's values
     */
    int opApply(scope int delegate(ref V v) dg)
    {
        int _dg(ref bool doPurge, ref V v)
        {
            return dg(v);
        }
        return purge(&_dg);
    }

    static if(doUnittest) unittest
    {
        auto tms = new TreeMultiset;
        tms.add([1, 2, 3, 4, 5]);
        uint[V] cnt;
        uint len = 0;
        foreach(i; tms)
        {
            assert(tms.contains(i));
            ++cnt[i];
            ++len;
        }
        assert(len == tms.length);
        foreach(k, v; cnt)
        {
            assert(tms.count(k) == v);
        }
    }

    /**
     * Instantiate the tree multiset
     */
    this()
    {
        _tree.setup();
    }

    //
    // for dup
    //
    private this(ref Impl dupFrom)
    {
        _tree.setup();
        dupFrom.copyTo(_tree);
    }

    /**
     * Clear the collection of all elements
     */
    TreeMultiset clear()
    {
        _tree.clear();
        return this;
    }

    static if(doUnittest) unittest
    {
        auto tms = new TreeMultiset;
        tms.add([1, 2, 2, 3, 3, 4, 5]);
        assert(tms.length == 7);
        tms.clear();
        assert(tms.length == 0);
    }

    /**
     * returns number of elements in the collection
     */
    @property uint length() const
    {
        return _tree.count;
    }

    /**
     * returns a cursor to the first element in the collection.
     */
    @property cursor begin()
    {
        cursor it;
        it.ptr = _tree.begin;
        it._empty = (_tree.count == 0);
        return it;
    }

    /**
     * returns a cursor that points just past the last element in the
     * collection.
     */
    @property cursor end()
    {
        cursor it;
        it.ptr = _tree.end;
        it._empty = true;
        return it;
    }

    /**
     * remove the element pointed at by the given cursor, returning an
     * cursor that points to the next element in the collection.
     *
     * Note that it is legal to pass an empty cursor.  This does nothing to the
     * collection, but returns the next valid cursor or end if the cursor
     * points to end.
     *
     * Runs in O(lg(n)) time.
     */
    cursor remove(cursor it)
    {
        if(!it.empty)
        {
            it.ptr = _tree.remove(it.ptr);
        }
        it._empty = (it.ptr == _tree.end);
        return it;
    }

    static if(doUnittest) unittest
    {
        auto tms = new TreeMultiset;
        tms.add([1, 2, 2, 3, 3, 4, 5]);
        tms.remove(tms.elemAt(3));
        assert(tms.arrayEqual([1, 2, 2, 3, 4, 5]));
    }

    /**
     * remove all the elements in the given range.
     */
    cursor remove(range r)
    {
        auto b = r.begin;
        auto e = r.end;
        while(b != e)
        {
            b = remove(b);
        }
        return b;
    }

    static if(doUnittest) unittest
    {
        auto tms = new TreeMultiset;
        tms.add([1, 2, 2, 3, 3, 4, 5]);
        auto r = tms[tms.elemAt(3)..tms.end];
        V[7] buf;
        auto remaining = std.algorithm.copy(tms[tms.begin..tms.elemAt(3)], buf[]);
        tms.remove(r);
        assert(tms.arrayEqual(buf[0..buf.length - remaining.length]));
        assert(!tms.contains(3));
    }

    /**
     * get a slice of all the elements in this collection.
     */
    range opSlice()
    {
        range result;
        result._begin = _tree.begin;
        result._end = _tree.end;
        return result;
    }

    /*
     * Create a range without checks to make sure b and e are part of the
     * collection.
     */
    private range _slice(cursor b, cursor e)
    {
        range result;
        result._begin = b.ptr;
        result._end = e.ptr;
        return result;
    }

    /**
     * get a slice of the elements between the two cursors.
     *
     * We rely on the implementation to verify the ordering of the cursors.  It
     * is possible to determine ordering, even for cursors with equal values,
     * in O(lgn) time.
     */
    range opSlice(cursor b, cursor e)
    {
        int order;
        if(_tree.positionCompare(b.ptr, e.ptr, order) && order <= 0)
        {
            // both cursors are part of the tree map and are correctly ordered.
            return _slice(b, e);
        }
        throw new Exception("invalid slice parameters to " ~ TreeMultiset.stringof);
    }

    /**
     * Create a slice based on values instead of based on cursors.
     *
     * b must be <= e, and b and e must both match elements in the collection.
     * Note that e cannot match end, so in order to get *all* the elements, you
     * must call the opSlice(V, end) version of the function.
     *
     * Note, a valid slice is only returned if both b and e exist in the
     * collection.
     *
     * runs in O(lgn) time.
     */
    range opSlice(V b, V e)
    {
        if(compareFunction(b, e) <= 0)
        {
            auto belem = elemAt(b);
            auto eelem = elemAt(e);
            // note, no reason to check for whether belem and eelem are members
            // of the tree, we just verified that!
            if(!belem.empty && !eelem.empty)
            {
                return _slice(belem, eelem);
            }
        }
        throw new Exception("invalid slice parameters to " ~ TreeMultiset.stringof);
    }

    /**
     * Slice between a value and a cursor.
     *
     * runs in O(lgn) time.
     */
    range opSlice(V b, cursor e)
    {
        auto belem = elemAt(b);
        if(!belem.empty)
        {
            int order;
            if(_tree.positionCompare(belem.ptr, e.ptr, order) && order <= 0)
            {
                return _slice(belem, e);
            }
        }
        throw new Exception("invalid slice parameters to " ~ TreeMultiset.stringof);
    }

    /**
     * Slice between a cursor and a key
     *
     * runs in O(lgn) time.
     */
    range opSlice(cursor b, V e)
    {
        auto eelem = elemAt(e);
        if(!eelem.empty)
        {
            int order;
            if(_tree.positionCompare(b.ptr, eelem.ptr, order) && order <= 0)
            {
                return _slice(b, eelem);
            }
        }
        throw new Exception("invalid slice parameters to " ~ TreeMultiset.stringof);
    }

    static if (doUnittest) unittest
    {
        auto tms = new TreeMultiset;
        tms.add([1, 2, 2, 3, 3, 4, 5]);
        auto fr = tms[];
        auto prev = fr.front;
        while(fr.front == prev)
            fr.popFront();
        auto cu = fr.begin;
        auto r = tms[tms.begin..cu];
        auto r2 = tms[cu..tms.end];
        foreach(x; r2)
        {
            assert(std.algorithm.find(r, x).empty);
        }
        assert(walkLength(r) + walkLength(r2) == tms.length);

        bool exceptioncaught = false;
        try
        {
            tms[cu..cu];
        }
        catch(Exception)
        {
            exceptioncaught = true;
        }
        assert(!exceptioncaught);

        // test slicing using improperly ordered cursors
        exceptioncaught = false;
        try
        {
            auto cu2 = cu;
            cu2.popFront();
            tms[cu2..cu];
        }
        catch(Exception)
        {
            exceptioncaught = true;
        }
        assert(exceptioncaught);

        // test slicing using values
        assert(std.algorithm.equal(tms[2..4], cast(V[])[2, 2, 3, 3]));

        assert(std.algorithm.equal(tms[tms.elemAt(2)..4], cast(V[])[2, 2, 3, 3]));
        assert(std.algorithm.equal(tms[2..tms.elemAt(4)], cast(V[])[2, 2, 3, 3]));

        // test slicing using improperly ordered values
        exceptioncaught = false;
        try
        {
            tms[4..2];
        }
        catch(Exception)
        {
            exceptioncaught = true;
        }
        assert(exceptioncaught);

        // test slicing using improperly ordered cursors
        exceptioncaught = false;
        try
        {
            tms[tms.elemAt(4)..2];
        }
        catch(Exception)
        {
            exceptioncaught = true;
        }
        assert(exceptioncaught);

        // test slicing using improperly ordered cursors
        exceptioncaught = false;
        try
        {
            tms[4..tms.elemAt(2)];
        }
        catch(Exception)
        {
            exceptioncaught = true;
        }
        assert(exceptioncaught);

    }

    /**
     * find the first instance of a given value in the collection.  Returns
     * end if the value is not present.
     *
     * Runs in O(lg(n)) time.
     */
    cursor elemAt(V v)
    {
        cursor it;
        it.ptr = _tree.find(v);
        it._empty = it.ptr == _tree.end;
        return it;
    }

    static if(doUnittest) unittest
    {
        auto tms = new TreeMultiset;
        tms.add([1, 2, 2, 3, 3, 4, 5]);
        assert(tms.elemAt(6).empty);
    }

    range allElemsAt(V v)
    {
        range r;
        auto elem = _tree.find(v);
        r._begin = elem;
        while(elem !is _tree.end && elem.value == v)
            elem = elem.next;
        r._end = elem;
        return r;
    }

    static if(doUnittest) unittest
    {
        auto tms = new TreeMultiset;
        tms.add([1, 2, 2, 3, 3, 4, 5]);
        assert(tms.allElemsAt(6).empty);
        assert(std.algorithm.equal(tms.allElemsAt(2), cast(V[])[2, 2]));
    }

    /**
     * Returns true if the given value exists in the collection.
     *
     * Runs in O(lg(n)) time.
     */
    bool contains(V v)
    {
        return !elemAt(v).empty;
    }

    /**
     * Removes the first element that has the value v.  Returns true if the
     * value was present and was removed.
     *
     * Runs in O(lg(n)) time.
     */
    TreeMultiset remove(V v)
    {
        remove(elemAt(v));
        return this;
    }

    /**
     * Removes the first element that has the value v.  Returns true if the
     * value was present and was removed.
     *
     * Runs in O(lg(n)) time.
     */
    TreeMultiset remove(V v, out bool wasRemoved)
    {
        cursor it = elemAt(v);
        wasRemoved = !it.empty;
        remove(it);
        return this;
    }

    static if(doUnittest) unittest
    {
        auto tms = new TreeMultiset;
        tms.add([1, 2, 2, 3, 3, 4, 5]);
        bool wasRemoved;
        tms.remove(1, wasRemoved);
        assert(tms.arrayEqual([2, 2, 3, 3, 4, 5]));
        assert(wasRemoved);
        tms.remove(10, wasRemoved);
        assert(tms.arrayEqual([2, 2, 3, 3, 4, 5]));
        assert(!wasRemoved);
        tms.remove(3);
        assert(tms.arrayEqual([2, 2, 3, 4, 5]));
    }

    /**
     * Adds a value to the collection.
     * Returns this.
     *
     * Runs in O(lg(n)) time.
     */
    TreeMultiset add(V v)
    {
        _tree.add(v);
        return this;
    }

    /**
     * Adds a value to the collection. Sets wasAdded to true if the value was
     * added.
     *
     * Returns this.
     *
     * Runs in O(lg(n)) time.
     */
    TreeMultiset add(V v, out bool wasAdded)
    {
        wasAdded = _tree.add(v);
        return this;
    }

    /**
     * Adds all the values from the iterator to the collection.
     *
     * Runs in O(m lg(n)) time, where m is the number of elements in
     * the iterator.
     */
    TreeMultiset add(Iterator!(V) it)
    {
        if(it is this)
            throw new Exception("Attempting to self add " ~ TreeMultiset.stringof);
        foreach(v; it)
            _tree.add(v);
        return this;
    }

    /**
     * Adds all the values from the iterator to the collection. Sets numAdded
     * to the number of values added from the iterator.
     *
     * Runs in O(m lg(n)) time, where m is the number of elements in
     * the iterator.
     */
    TreeMultiset add(Iterator!(V) it, out uint numAdded)
    {
        uint origlength = length;
        add(it);
        numAdded = length - origlength;
        return this;
    }

    /**
     * Adds all the values from array to the collection.
     *
     * Runs in O(m lg(n)) time, where m is the number of elements in
     * array.
     */
    TreeMultiset add(V[] array)
    {
        foreach(v; array)
            _tree.add(v);
        return this;
    }

    /**
     * Adds all the values from array to the collection.  Sets numAdded to the
     * number of elements added from the array.
     *
     * Runs in O(m lg(n)) time, where m is the number of elements in
     * array.
     */
    TreeMultiset add(V[] array, out uint numAdded)
    {
        uint origlength = length;
        add(array);
        numAdded = length - origlength;
        return this;
    }

    static if(doUnittest) unittest
    {
        // add single element
        bool wasAdded = false;
        auto tms = new TreeMultiset;
        tms.add(1);
        tms.add(2, wasAdded);
        assert(tms.length == 2);
        assert(tms.arrayEqual([1, 2]));
        assert(wasAdded);

        // add a duplicate element
        wasAdded = false;
        tms.add(2, wasAdded);
        assert(wasAdded);
        assert(tms.arrayEqual([1, 2, 2]));

        // add other collection
        uint numAdded = 0;
        // need to add duplicate, adding self is not allowed.
        auto hs2 = tms.dup;
        hs2.add(3);
        tms.add(hs2, numAdded);
        tms.add(tms.dup);
        bool caughtexception = false;
        try
        {
            tms.add(tms);
        }
        catch(Exception)
        {
            caughtexception = true;
        }
        // should not be able to add self
        assert(caughtexception);

        assert(tms.arrayEqual([1, 1, 1, 1, 2, 2, 2, 2, 2, 2, 2, 2, 3, 3]));
        assert(numAdded == 4);

        // add array
        tms.clear();
        tms.add([1, 2, 3, 4, 5]);
        tms.add([3, 4, 5, 6, 7], numAdded);
        assert(tms.arrayEqual([1, 2, 3, 3, 4, 4, 5, 5, 6, 7]));
        assert(numAdded == 5);
    }

    /**
     * Returns the number of elements in the collection that are equal to v.
     *
     * Runs in O(m lg(n)) time, where m is the number of elements that are v.
     */
    uint count(V v)
    {
        return _tree.countAll(v);
    }

    /**
     * Removes all the elements that are equal to v.
     *
     * Runs in O(m lg(n)) time, where m is the number of elements that are v.
     */
    TreeMultiset removeAll(V v)
    {
        _tree.removeAll(v);
        return this;
    }
    
    /**
     * Removes all the elements that are equal to v.  Sets numRemoved to the
     * number of elements removed from the multiset.
     *
     * Runs in O(m lg(n)) time, where m is the number of elements that are v.
     */
    TreeMultiset removeAll(V v, out uint numRemoved)
    {
        numRemoved = _tree.removeAll(v);
        return this;
    }

    static if(doUnittest) unittest
    {
        auto tms = new TreeMultiset;
        tms.add([1, 2, 2, 3, 3, 4, 5]);
        assert(tms.count(1) == 1);
        assert(tms.count(2) == 2);
        assert(tms.count(3) == 2);
        uint numRemoved = 0;
        tms.removeAll(2, numRemoved);
        assert(numRemoved == 2);
        assert(tms.arrayEqual([1, 3, 3, 4, 5]));
        tms.removeAll(10, numRemoved);
        assert(numRemoved == 0);
        assert(tms.arrayEqual([1, 3, 3, 4, 5]));
        tms.removeAll(3);
        assert(tms.arrayEqual([1, 4, 5]));
    }

    /**
     * duplicate this tree multiset
     */
    TreeMultiset dup()
    {
        return new TreeMultiset(_tree);
    }

    /**
     * get the most convenient element in the set.  This is the element that
     * would be iterated first.  Therefore, calling remove(get()) is
     * guaranteed to be less than an O(n) operation.
     */
    @property V get()
    {
        return begin.front;
    }

    static if(doUnittest) unittest
    {
        auto tms = new TreeMultiset;
        tms.add([1, 2, 2, 3, 3, 4, 5]);
        assert(!std.algorithm.find([1, 2, 3, 4, 5], tms.get()).empty);
    }

    /**
     * Remove the most convenient element from the set, and return its value.
     * This is equivalent to remove(get()), except that only one lookup is
     * performed.
     */
    V take()
    {
        auto c = begin;
        auto retval = c.front;
        remove(c);
        return retval;
    }

    static if(doUnittest) unittest
    {
        auto tms = new TreeMultiset;
        V[] aa = [1, 2, 2, 3, 3, 4, 5];
        tms.add(aa);
        auto x = tms.take();
        assert(!std.algorithm.find([1, 2, 3, 4, 5], x).empty);
        // remove x from the original array, and check for equality
        std.algorithm.partition!((V a) {return a == x;})(aa);
        assert(tms.arrayEqual(aa[1..$]));
    }
}

unittest
{
    // declare the Link list types that should be unit tested.
    TreeMultiset!ubyte  tms1;
    TreeMultiset!byte   tms2;
    TreeMultiset!ushort tms3;
    TreeMultiset!short  tms4;
    TreeMultiset!uint   tms5;
    TreeMultiset!int    tms6;
    TreeMultiset!ulong  tms7;
    TreeMultiset!long   tms8;
}
