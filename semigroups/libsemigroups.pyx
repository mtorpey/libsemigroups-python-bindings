# cython: infer_types=True, embedsignature=True
"""
Python bindings for the libsemigroups C++ library.

`libsemigroups <https://github.com/james-d-mitchell/libsemigroups/>`_
is a C++ mathematical library for computing with finite `semigroups
<https://en.wikipedia.org/wiki/Semigroup>`_. This Cython module
provides bindings to call it from Python.

We construct the semigroup generated by `0` and `-1`::

    >>> from semigroups import Semigroup
    >>> S = Semigroup([0,-1])
    >>> S.size()
    3

We construct the semigroup generated by `0` and complex number `i`::

    >>> S = Semigroup([0, 1j])
    >>> S.size()
    5
"""
cimport libsemigroups_cpp as libsemigroups

from libc.stdint cimport uint16_t
from libcpp.vector cimport vector
from libcpp cimport bool
from libcpp.string cimport string
from libcpp.pair cimport pair
from libc.stdint cimport uint32_t

from cysignals.signals cimport sig_on, sig_off

cdef class __dummyClass:
    def __init__(self):
        pass

cdef class CyElement:
    """
    An abstract base class for handles to libsemigroups elements.

    Any subclass shall implement an ''__init__'' method which
    initializes _handle.
    """
    cdef libsemigroups.Element* _handle

    def __cinit__(self):
        self._handle = NULL

    def __dealloc__(self):
        if self._handle != NULL:
            self._handle[0].really_delete()
            del self._handle

    def __mul__(CyElement self, CyElement other):
        cdef libsemigroups.Element* product = self._handle.identity()
        product.redefine(self._handle, other._handle)
        return self.new_from_handle(product)
  
    def __richcmp__(CyElement self, CyElement other, int op):
        if op == 0:
            return self._handle[0] < other._handle[0]
        elif op == 1:
            return (self._handle[0] < other._handle[0] 
                    or self._handle[0] == other._handle[0])
        elif op == 2:
            return self._handle[0] == other._handle[0]
        elif op == 3:
            return not self._handle[0] == other._handle[0]
        elif op == 4:
            return not (self._handle[0] < other._handle[0] 
                        or self._handle[0] == other._handle[0])
        elif op == 5:
            return not self._handle[0] < other._handle[0]

    cdef new_from_handle(self, libsemigroups.Element* handle):
        cdef CyElement result = self.__class__(__dummyClass)
        result._handle = handle[0].really_copy()
        return result

    def degree(self):
        return self._handle.degree()

    def identity(self):
        cdef libsemigroups.Element* identity = self._handle.identity()
        return self.new_from_handle(identity)

cdef class CyTransformation(CyElement):
    def __init__(self, images):
        if images is not __dummyClass:
            self._handle = new libsemigroups.Transformation[uint16_t](images)

    def __iter__(self):
        cdef libsemigroups.Element* e = self._handle
        e2 = <libsemigroups.Transformation[uint16_t] *>e
        for x in e2[0]:
            yield x

cdef class CyPartialPerm(CyElement):
    def __init__(self, images):
        if images is not __dummyClass:
            self._handle = new libsemigroups.PartialPerm[uint16_t](images)

    def __iter__(self):
        cdef libsemigroups.Element* e = self._handle
        e2 = <libsemigroups.PartialPerm[uint16_t] *>e
        for x in e2[0]:
            yield x

    def rank(self):
        cdef libsemigroups.Element* e = self._handle
        e2 = <libsemigroups.PartialPerm[uint16_t] *>e
        return e2.crank()

cdef class CyBipartition(CyElement):
    def __init__(self, blocks_lookup):
        if blocks_lookup is not __dummyClass:
            self._handle = new libsemigroups.Bipartition(blocks_lookup)

    def __iter__(self):
        cdef libsemigroups.Element* e = self._handle
        e2 = <libsemigroups.Bipartition *>e
        for x in e2[0]:
            yield x

    def nr_blocks(self):
        cdef libsemigroups.Element* e = self._handle
        e2 = <libsemigroups.Bipartition *>e
        return e2.const_nr_blocks()

    def block(self, index):
        cdef libsemigroups.Element* e = self._handle
        e2 = <libsemigroups.Bipartition *>e
        return e2.block(index)

    def is_transverse_block(self, index):
        cdef libsemigroups.Element* e = self._handle
        e2 = <libsemigroups.Bipartition *>e
        return e2.is_transverse_block(index)

cdef class CyBooleanMat(CyElement):
    def __init__(self, rows):
        if rows is not __dummyClass:
            self._handle = new libsemigroups.BooleanMat(rows)

    def __iter__(self): # iterate through values in the matrix
        cdef libsemigroups.Element* e = self._handle
        e2 = <libsemigroups.BooleanMat *>e
        for x in e2[0]:
            yield x

cdef class CyPBR(CyElement):
    def __init__(self, adj):
        if adj is not __dummyClass:
            self._handle = new libsemigroups.PBR(adj)

    def __iter__(self):
        cdef libsemigroups.Element* e = self._handle
        e2 = <libsemigroups.PBR *>e
        for x in e2[0]:
            yield x

cdef class PythonElement(CyElement):
    """
    A class for handles to libsemigroups elements that themselves wrap
    back a Python element

    EXAMPLE::

        >>> from semigroups import Semigroup, PythonElement
        >>> x = PythonElement(-1); x
        -1

        >>> Semigroup([PythonElement(-1)]).size()
        2
        >>> Semigroup([PythonElement(1)]).size()
        1
        >>> Semigroup([PythonElement(0)]).size()
        1
        >>> Semigroup([PythonElement(0), PythonElement(-1)]).size()
        3

        x = [PythonElement(-1)]
        x = 2

        sage: W = SymmetricGroup(4)
        sage: pi = W.simple_projections()
        sage: F = FiniteSetMaps(W)
        sage: S = Semigroup([PythonElement(F(p)) for p in pi])
        sage: S.size()
        23

    TESTS::

        Testing reference counting::

            >>> s = "UN NOUVEL OBJET"
            >>> sys.getrefcount(s)
            2
            >>> x = PythonElement(s)
            >>> sys.getrefcount(s)
            3
            >>> del x
            >>> sys.getrefcount(s)
            2
    """
    def __init__(self, value):
        if value is not None:
            self._handle = new libsemigroups.PythonElement(value)

    def get_value(self):
        """

        """
        return (<libsemigroups.PythonElement *>self._handle).get_value()

    def __repr__(self):
        return repr(self.get_value())


# TODO Currently there seems to be no point in putting this into semigrp.py
# since almost every method has no checks but just calls the corresponding
# method for the C++ object. 

cdef class CySemigroup:
    # holds a pointer to the C++ instance which we're wrapping
    cdef libsemigroups.Semigroup* _handle      
    cdef CyElement _an_element

    def __cinit__(self):
        self._handle = NULL

    def __init__(self, gens):
        cdef vector[libsemigroups.Element *] cpp_gens
        for g in gens:
            cpp_gens.push_back((<CyElement>g)._handle)
        self._handle = new libsemigroups.Semigroup(cpp_gens)
        self._an_element = gens[0]

    def __dealloc__(self):
        del self._handle

    def current_max_word_length(self):
        return self._handle.current_max_word_length()

    def nridempotents(self):
        return self._handle.nridempotents()
    
    def is_done(self):
        return self._handle.is_done()
    
    def is_begun(self):
        return self._handle.is_begun()
    
    def current_position(self, CyElement x):
        pos = self._handle.current_position(x._handle)
        if pos == -1:
            return None # TODO Ok?
        return pos
    
    def __contains__(self, CyElement x):
        return self._handle.test_membership(x._handle)

    def set_report(self, val):
        if val == True:
            self._handle.set_report(1)
        else:
            self._handle.set_report(0)

    def factorisation(self, CyElement x):
        '''
        >>> import from semigroups *
        >>> S = FullTransformationMonoid(5)
        >>> S.factorisation(Transformation([0] * 5))
        [1, 0, 2, 1, 0, 2, 1, 0, 2, 1]
        >>> S[1] * S[0] * S[2] * S[1] * S[0] * S[2] * S[1] * S[0] * S[2] * S[1]
        '''
        pos = self._handle.position(x._handle)
        if pos == -1:
            return None # TODO Ok?
        cdef vector[size_t]* c_word = self._handle.factorisation(pos)
        assert c_word != NULL
        py_word = [letter for letter in c_word[0]]
        del c_word
        return py_word
    
    def enumerate(self, limit):
        self._handle.enumerate(limit)

    def size(self):
        """
        Return the size of this semigroup

        EXAMPLES::

            >>> from semigroups import Semigroup, Transformation
            >>> S = Semigroup([Transformation([1, 1, 4, 5, 4, 5]),
            ...                Transformation([2, 3, 2, 3, 5, 5])])
            >>> S.size()
            5
        """
        # Plausibly wrap in sig_off / sig_on
        return self._handle.size()

    cdef new_from_handle(self, libsemigroups.Element* handle):
        return self._an_element.new_from_handle(handle)

    def __getitem__(self, size_t pos):
        """
        Return the ``pos``-th element of ``self``.

        EXAMPLES::

            >>> from semigroups import Semigroup
            >>> S = Semigroup([1j])
            >>> S[0]
            1j
            >>> S[1]
            (-1+0j)
            >>> S[2]
            (-0-1j)
            >>> S[3]
            (1-0j)
        """
        cdef libsemigroups.Element* element
        element = self._handle.at(pos)
        if element == NULL:
            return None
        else:
            return self.new_from_handle(element)

    def __iter__(self):
        """
        An iterator over the elements of self.

        EXAMPLES::

            >>> from semigroups import Semigroup
            >>> S = Semigroup([1j])
            >>> for x in S:
            ...     print(x)
            1j
            (-1+0j)
            (-0-1j)
            (1-0j)
        """
        cdef size_t pos = 0
        cdef libsemigroups.Element* element
        while True:
            element = self._handle.at(pos)
            if element == NULL:
                break
            else:
                yield self.new_from_handle(element)
            pos += 1


# FIXME should be a subclass of CySemigroup
cdef class FpSemigroupNC:
    cdef libsemigroups.Congruence* _congruence
    cdef libsemigroups.RWS* _rws
    
    def __convert_word(self, word):
        return [self.alphabet.index(i) for i in word]

    def __convert_rel(self, rel):
        return [self.__convert_word(w) for w in rel]

    def __init__(self, nrgens, rels):
        rels = [self.__convert_rel(rel) for rel in rels]
        self._congruence = new libsemigroups.Congruence("twosided",
                                                        nrgens,
                                                        [],
                                                        rels)
        self._rws = new libsemigroups.RWS(rels)
    
    def __dealloc__(self):
        del self._congruence
        del self._rws

    def size(self):
        sig_on()
        try:
            return self._congruence.nr_classes()
        finally:
            sig_off()
        # FIXME must actually kill off the nr_classes process safely

    def set_report(self, val):
        '''
        toggles whether or not to report data when running certain functions

        Args:
            bool:toggle to True or False
        '''
        if val != True and val != False:
            raise TypeError('the argument must be True or False')
        if val:
            self._congruence.set_report(1)
        else:
            self._congruence.set_report(0)

    def set_max_threads(self, nr_threads):
        '''
        sets the maximum number of threads to be used at once.

        Args:
            int:number of threads
        '''
        return self._congruence.set_max_threads(nr_threads)

    def is_confluent(self):
        '''
        check if the relations of the FpSemigroup are confluent.

        Examples:
            >>> FpSemigroup(["a","b"],[["aa","a"],["bbb","ab"],
                                                  ["ab","ba"]).is_confluent()
            True
            >>> FpSemigroup(["a","b"],[["aa","a"],["bab","ab"],
                                                  ["ab","ba"]).is_confluent()
            False

        Returns:
            bool: True for confluent, False otherwise.
        '''
        return self._rws.is_confluent()

    def word_to_class_index(self, word):
        return self._congruence.word_to_class_index(self.__convert_word(word))
