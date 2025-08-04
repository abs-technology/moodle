<?php

class __Mustache_205f62f0acb75ee4580c2f0b4a4a1858 extends Mustache_Template
{
    private $lambdaHelper;

    public function renderInternal(Mustache_Context $context, $indent = '')
    {
        $this->lambdaHelper = new Mustache_LambdaHelper($this->mustache, $context);
        $buffer = '';

        if ($parent = $this->mustache->loadPartial('core_form/element-template')) {
            $context->pushBlockContext(array(
                'label' => array($this, 'block8ba734896a39b23a48efef3f149d2495'),
                'element' => array($this, 'blockBcc84fe7b13e38609ab8facc8e48d518'),
            ));
            $buffer .= $parent->renderInternal($context, $indent);
            $context->popBlockContext();
        }
        $value = $context->find('js');
        $buffer .= $this->section6d2e2e87fc481d895296783fc460fcbb($context, $indent, $value);

        return $buffer;
    }

    private function section7ba672f1b2cab39c23438b6336d8ba28(Mustache_Context $context, $indent, $value)
    {
        $buffer = '';
    
        if (!is_string($value) && is_callable($value)) {
            $source = '
                    {{{separator}}}
                    {{{html}}}
                ';
            $result = (string) call_user_func($value, $source, $this->lambdaHelper);
            $buffer .= $result;
        } elseif (!empty($value)) {
            $values = $this->isIterable($value) ? $value : array($value);
            foreach ($values as $value) {
                $context->push($value);
                
                $buffer .= $indent . '                    ';
                $value = $this->resolveValue($context->find('separator'), $context);
                $buffer .= ($value === null ? '' : $value);
                $buffer .= '
';
                $buffer .= $indent . '                    ';
                $value = $this->resolveValue($context->find('html'), $context);
                $buffer .= ($value === null ? '' : $value);
                $buffer .= '
';
                $context->pop();
            }
        }
    
        return $buffer;
    }

    private function sectionF96aa9ea145d96fcbe64a920ab06e374(Mustache_Context $context, $indent, $value)
    {
        $buffer = '';
    
        if (!is_string($value) && is_callable($value)) {
            $source = '
            <fieldset class="w-100 m-0 p-0 border-0">
                <legend class="visually-hidden">{{label}}</legend>
                <div class="d-flex flex-wrap align-items-center">
                {{#element.elements}}
                    {{{separator}}}
                    {{{html}}}
                {{/element.elements}}
                </div>
            </fieldset>
        ';
            $result = (string) call_user_func($value, $source, $this->lambdaHelper);
            $buffer .= $result;
        } elseif (!empty($value)) {
            $values = $this->isIterable($value) ? $value : array($value);
            foreach ($values as $value) {
                $context->push($value);
                
                $buffer .= $indent . '            <fieldset class="w-100 m-0 p-0 border-0">
';
                $buffer .= $indent . '                <legend class="visually-hidden">';
                $value = $this->resolveValue($context->find('label'), $context);
                $buffer .= ($value === null ? '' : call_user_func($this->mustache->getEscape(), $value));
                $buffer .= '</legend>
';
                $buffer .= $indent . '                <div class="d-flex flex-wrap align-items-center">
';
                $value = $context->findDot('element.elements');
                $buffer .= $this->section7ba672f1b2cab39c23438b6336d8ba28($context, $indent, $value);
                $buffer .= $indent . '                </div>
';
                $buffer .= $indent . '            </fieldset>
';
                $context->pop();
            }
        }
    
        return $buffer;
    }

    private function section6d2e2e87fc481d895296783fc460fcbb(Mustache_Context $context, $indent, $value)
    {
        $buffer = '';
    
        if (!is_string($value) && is_callable($value)) {
            $source = '
require([\'jquery\'], function($) {
    $(\'#{{element.id}}_label\').css(\'cursor\', \'default\');
    $(\'#{{element.id}}_label\').click(function() {
        $(\'#{{element.id}}, [data-groupname="{{element.name}}"]\')
            .find(\'button, a, input:not([type="hidden"]), select, textarea, [tabindex]\')
            .filter(\':not([disabled]):not([tabindex="0"]):not([tabindex="-1"])\')
            .first().focus();
    });
});
';
            $result = (string) call_user_func($value, $source, $this->lambdaHelper);
            $buffer .= $result;
        } elseif (!empty($value)) {
            $values = $this->isIterable($value) ? $value : array($value);
            foreach ($values as $value) {
                $context->push($value);
                
                $buffer .= $indent . 'require([\'jquery\'], function($) {
';
                $buffer .= $indent . '    $(\'#';
                $value = $this->resolveValue($context->findDot('element.id'), $context);
                $buffer .= ($value === null ? '' : call_user_func($this->mustache->getEscape(), $value));
                $buffer .= '_label\').css(\'cursor\', \'default\');
';
                $buffer .= $indent . '    $(\'#';
                $value = $this->resolveValue($context->findDot('element.id'), $context);
                $buffer .= ($value === null ? '' : call_user_func($this->mustache->getEscape(), $value));
                $buffer .= '_label\').click(function() {
';
                $buffer .= $indent . '        $(\'#';
                $value = $this->resolveValue($context->findDot('element.id'), $context);
                $buffer .= ($value === null ? '' : call_user_func($this->mustache->getEscape(), $value));
                $buffer .= ', [data-groupname="';
                $value = $this->resolveValue($context->findDot('element.name'), $context);
                $buffer .= ($value === null ? '' : call_user_func($this->mustache->getEscape(), $value));
                $buffer .= '"]\')
';
                $buffer .= $indent . '            .find(\'button, a, input:not([type="hidden"]), select, textarea, [tabindex]\')
';
                $buffer .= $indent . '            .filter(\':not([disabled]):not([tabindex="0"]):not([tabindex="-1"])\')
';
                $buffer .= $indent . '            .first().focus();
';
                $buffer .= $indent . '    });
';
                $buffer .= $indent . '});
';
                $context->pop();
            }
        }
    
        return $buffer;
    }

    public function block8ba734896a39b23a48efef3f149d2495($context)
    {
        $indent = $buffer = '';
        $value = $context->findDot('element.hiddenlabel');
        if (empty($value)) {
            
            $buffer .= $indent . '            <p id="';
            $value = $this->resolveValue($context->findDot('element.id'), $context);
            $buffer .= ($value === null ? '' : call_user_func($this->mustache->getEscape(), $value));
            $buffer .= '_label" class="mb-0 word-break" aria-hidden="true">
';
            $buffer .= $indent . '                ';
            $value = $this->resolveValue($context->find('label'), $context);
            $buffer .= ($value === null ? '' : $value);
            $buffer .= '
';
            $buffer .= $indent . '            </p>
';
        }
    
        return $buffer;
    }

    public function blockBcc84fe7b13e38609ab8facc8e48d518($context)
    {
        $indent = $buffer = '';
        $value = $context->find('label');
        $buffer .= $this->sectionF96aa9ea145d96fcbe64a920ab06e374($context, $indent, $value);
        $value = $context->find('label');
        if (empty($value)) {
            
            $buffer .= $indent . '            <div class="w-100 m-0 p-0 border-0">
';
            $buffer .= $indent . '                <div class="d-flex flex-wrap align-items-center">
';
            $value = $context->findDot('element.elements');
            $buffer .= $this->section7ba672f1b2cab39c23438b6336d8ba28($context, $indent, $value);
            $buffer .= $indent . '                </div>
';
            $buffer .= $indent . '            </div>
';
        }
    
        return $buffer;
    }
}
