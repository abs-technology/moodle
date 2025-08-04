<?php

class __Mustache_e7b632e55a47ab1393a1b1710a2c40bb extends Mustache_Template
{
    public function renderInternal(Mustache_Context $context, $indent = '')
    {
        $buffer = '';

        $buffer .= $indent . '
';
        $buffer .= $indent . '<div class="divider bulk-hidden d-flex justify-content-center align-items-center ';
        $blockFunction = $context->findInBlock('extraclasses');
        if (is_callable($blockFunction)) {
            $buffer .= call_user_func($blockFunction, $context);
        } else {
            $value = $this->resolveValue($context->find('extraclasses'), $context);
            $buffer .= ($value === null ? '' : call_user_func($this->mustache->getEscape(), $value));
        }
        $buffer .= '">
';
        $buffer .= $indent . '    <hr>
';
        $buffer .= $indent . '    <div class="divider-content px-3">
';
        $buffer .= $indent . '        ';
        $blockFunction = $context->findInBlock('content');
        if (is_callable($blockFunction)) {
            $buffer .= call_user_func($blockFunction, $context);
        } else {
            $value = $this->resolveValue($context->find('content'), $context);
            $buffer .= ($value === null ? '' : $value);
        }
        $buffer .= '
';
        $buffer .= $indent . '    </div>
';
        $buffer .= $indent . '</div>
';

        return $buffer;
    }
}
