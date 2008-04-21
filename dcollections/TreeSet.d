/*********************************************************
   Copyright: (C) 2008 by Steven Schveighoffer.
              All rights reserved

   License: $(LICENSE)

**********************************************************/
module dcollections.TreeSet;

public import dcollections.model.Set;

private import dcollections.RBTree;

/**
 * Implementation of the Set interface using Red-Black trees.  this allows for
 * O(lg(n)) insertion, removal, and lookup times.  It also creates a sorted
 * set.  V must be comparable.
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
 *   updateFunction -> the update function to use (should be an
 *                     UpdateFunction!(V))
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
 * tree, the 
 *
 * node begin -> must be a node that points to the very first valid
 * element in the tree, or end if no elements exist.
 *
 * node end -> must be a node that points to just past the very last
 * valid element.
 *
 * node find(V v) -> returns a node that points to the element that
 * contains v, or end if the element doesn't exist.
 *
 * node remove(node p) -> removes the given element from the tree,
 * returns the next valid element or end if p was last in the tree.
 *
 * void clear() -> removes all elements from the tree, sets count to 0.
 */
class TreeSet(V, alias ImplTemp = RBTree) : Set!(V)
{
    /**
     * convenience alias.
     */
    alias ImplTemp!(V) Impl;

    private Impl _tree;
    private Purger _purger;

    private static final int compareFunction(ref V e, ref V e2)
    {
        return typeid(V).compare(&e, &e2);
    }

    private static final void updateFunction(ref V orig, ref V newv)
    {
    }

    /**
     * Iterator for the tree set.
     */
    struct cursor
    {
        private Impl.node ptr;

        /**
         * get the value in this element
         */
        V value()
        {
            return ptr.value;
        }

        /**
         * increment this cursor, returns what the cursor was before
         * incrementing.
         */
        cursor opPostInc()
        {
            cursor tmp = *this;
            ptr = ptr.next;
            return tmp;
        }

        /**
         * decrement this cursor, returns what the cursor was before
         * decrementing.
         */
        cursor opPostDec()
        {
            cursor tmp = *this;
            ptr = ptr.prev;
            return tmp;
        }

        /**
         * increment the cursor by the given amount.
         *
         * This is an O(inc) operation!  You should only use this operator in
         * the form:
         *
         * ++i;
         */
        cursor opAddAssign(int inc)
        {
            if(inc < 0)
                return opSubAssign(-inc);
            while(inc--)
                ptr = ptr.next;
            return *this;
        }

        /**
         * decrement the cursor by the given amount.
         *
         * This is an O(inc) operation!  You should only use this operator in
         * the form:
         *
         * --i;
         */
        cursor opSubAssign(int inc)
        {
            if(inc < 0)
                return opAddAssign(-inc);
            while(inc--)
                ptr = ptr.prev;
            return *this;
        }

        /**
         * compare two cursors for equality
         */
        bool opEquals(cursor it)
        {
            return it.ptr is ptr;
        }
    }

    private class Purger : PurgeIterator!(V)
    {
        int opApply(int delegate(ref bool doPurge, ref V v) dg)
        {
            return _apply(dg);
        }
    }

    private int _apply(int delegate(ref bool doPurge, ref V v) dg)
    {
        cursor it = begin;
        bool doPurge;
        int dgret = 0;
        cursor _end = end; // cache end so it isn't always being generated
        while(!dgret && it != _end)
        {
            //
            // don't allow user to change value
            //
            V tmpvalue = it.value;
            doPurge = false;
            if((dgret = dg(doPurge, tmpvalue)) != 0)
                break;
            if(doPurge)
                it = remove(it);
            else
                it++;
        }
        return dgret;
    }

    /**
     * iterate over the collection's values
     */
    int opApply(int delegate(ref V v) dg)
    {
        int _dg(ref bool doPurge, ref V v)
        {
            return dg(v);
        }
        return _apply(&_dg);
    }

    /**
     * Instantiate the tree set using the implementation parameters given.
     */
    this(Impl.parameters p)
    {
        // insert defaults
        if(!p.updateFunction)
            p.updateFunction = &updateFunction;
        if(!p.compareFunction)
            p.compareFunction = &compareFunction;
        _tree.setup(p);
        _purger = new Purger;
    }

    /**
     * Instantiate the tree set using the default implementation parameters.
     */
    this()
    {
        Impl.parameters p;
        this(p);
    }

    /**
     * Clear the collection of all elements
     */
    Collection!(V) clear()
    {
        _tree.clear();
        return this;
    }

    /**
     * returns true
     */
    final bool supportsLength()
    {
        return true;
    }

    /**
     * returns number of elements in the collection
     */
    uint length()
    {
        return _tree.count;
    }

    /**
     * returns a cursor to the first element in the collection.
     */
    final cursor begin()
    {
        cursor it;
        it.ptr = _tree.begin;
        return it;
    }

    /**
     * returns a cursor that points just past the last element in the
     * collection.
     */
    final cursor end()
    {
        cursor it;
        it.ptr = _tree.end;
        return it;
    }

    /**
     * remove the element pointed at by the given cursor, returning an
     * cursor that points to the next element in the collection.
     *
     * Runs in O(lg(n)) time.
     */
    cursor remove(cursor it)
    {
        it.ptr = _tree.remove(it.ptr);
        return it;
    }

    /**
     * find the instance of a value in the collection.  Returns end if the
     * value is not present.
     *
     * Runs in O(lg(n)) time.
     */
    cursor find(V v)
    {
        cursor it;
        it.ptr = _tree.find(v);
        return it;
    }

    /**
     * Returns true if the given value exists in the collection.
     *
     * Runs in O(lg(n)) time.
     */
    bool contains(V v)
    {
        return find(v) != end;
    }

    /**
     * Removes the element that has the value v.  Returns true if the value
     * was present and was removed.
     *
     * Runs in O(lg(n)) time.
     */
    bool remove(V v)
    {
        cursor it = find(v);
        if(it == end)
            return false;
        remove(it);
        return true;
    }

    /**
     * returns an object that can be used to purge the collection.
     */
    PurgeIterator!(V) purger()
    {
        return _purger;
    }

    /**
     * Adds a value to the collection.
     * Returns true.
     *
     * Runs in O(lg(n)) time.
     */
    bool add(V v)
    {
        return _tree.add(v);
    }

    /**
     * Adds all the values from enumerator to the collection.
     *
     * Runs in O(m lg(n)) time, where m is the number of elements in
     * enumerator.
     */
    uint addAll(Iterator!(V) enumerator)
    {
        uint origlength = length;
        foreach(v; enumerator)
            _tree.add(v);
        return length - origlength;
    }

    /**
     * Adds all the values from array to the collection.
     *
     * Runs in O(m lg(n)) time, where m is the number of elements in
     * array.
     */
    uint addAll(V[] array)
    {
        uint origlength = length;
        foreach(v; array)
            _tree.add(v);
        return length - origlength;
    }
}
