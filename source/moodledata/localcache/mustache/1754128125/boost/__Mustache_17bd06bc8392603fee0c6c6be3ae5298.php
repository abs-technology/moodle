<?php

class __Mustache_17bd06bc8392603fee0c6c6be3ae5298 extends Mustache_Template
{
    private $lambdaHelper;

    public function renderInternal(Mustache_Context $context, $indent = '')
    {
        $this->lambdaHelper = new Mustache_LambdaHelper($this->mustache, $context);
        $buffer = '';

        $buffer .= $indent . '
';
        $value = $context->find('hasactionlinks');
        if (empty($value)) {
            
            if ($partial = $this->mustache->loadPartial('core_course/addresourceoractivitybutton')) {
                $buffer .= $partial->renderInternal($context, $indent . '    ');
            }
        }
        $buffer .= $indent . '
';
        $value = $context->find('hasactionlinks');
        $buffer .= $this->sectionC710fa7758aea7221eb21755c5c19be7($context, $indent, $value);

        return $buffer;
    }

    private function section3ad11aeb42e26704218191fae63bcb28(Mustache_Context $context, $indent, $value)
    {
        $buffer = '';
    
        if (!is_string($value) && is_callable($value)) {
            $source = '{{modid}}';
            $result = (string) call_user_func($value, $source, $this->lambdaHelper);
            $buffer .= $result;
        } elseif (!empty($value)) {
            $values = $this->isIterable($value) ? $value : array($value);
            foreach ($values as $value) {
                $context->push($value);
                
                $value = $this->resolveValue($context->find('modid'), $context);
                $buffer .= ($value === null ? '' : call_user_func($this->mustache->getEscape(), $value));
                $context->pop();
            }
        }
    
        return $buffer;
    }

    private function sectionAcd66ef23857ba2b241b6f8f23ef69c2(Mustache_Context $context, $indent, $value)
    {
        $buffer = '';
    
        if (!is_string($value) && is_callable($value)) {
            $source = ' {{activityname}} ';
            $result = (string) call_user_func($value, $source, $this->lambdaHelper);
            $buffer .= $result;
        } elseif (!empty($value)) {
            $values = $this->isIterable($value) ? $value : array($value);
            foreach ($values as $value) {
                $context->push($value);
                
                $buffer .= ' ';
                $value = $this->resolveValue($context->find('activityname'), $context);
                $buffer .= ($value === null ? '' : call_user_func($this->mustache->getEscape(), $value));
                $buffer .= ' ';
                $context->pop();
            }
        }
    
        return $buffer;
    }

    private function section244607ab42f64f3e7b0f1d4b2d5b2758(Mustache_Context $context, $indent, $value)
    {
        $buffer = '';
    
        if (!is_string($value) && is_callable($value)) {
            $source = 'insertcontentbefore, core, { "activityname": {{#quote}} {{activityname}} {{/quote}} } ';
            $result = (string) call_user_func($value, $source, $this->lambdaHelper);
            $buffer .= $result;
        } elseif (!empty($value)) {
            $values = $this->isIterable($value) ? $value : array($value);
            foreach ($values as $value) {
                $context->push($value);
                
                $buffer .= 'insertcontentbefore, core, { "activityname": ';
                $value = $context->find('quote');
                $buffer .= $this->sectionAcd66ef23857ba2b241b6f8f23ef69c2($context, $indent, $value);
                $buffer .= ' } ';
                $context->pop();
            }
        }
    
        return $buffer;
    }

    private function sectionA00193c143ddd0475f086db8f2764b8a(Mustache_Context $context, $indent, $value)
    {
        $buffer = '';
    
        if (!is_string($value) && is_callable($value)) {
            $source = '
            data-beforemod="{{modid}}"
            aria-label="{{#str}}insertcontentbefore, core, { "activityname": {{#quote}} {{activityname}} {{/quote}} } {{/str}}"
            ';
            $result = (string) call_user_func($value, $source, $this->lambdaHelper);
            $buffer .= $result;
        } elseif (!empty($value)) {
            $values = $this->isIterable($value) ? $value : array($value);
            foreach ($values as $value) {
                $context->push($value);
                
                $buffer .= $indent . '            data-beforemod="';
                $value = $this->resolveValue($context->find('modid'), $context);
                $buffer .= ($value === null ? '' : call_user_func($this->mustache->getEscape(), $value));
                $buffer .= '"
';
                $buffer .= $indent . '            aria-label="';
                $value = $context->find('str');
                $buffer .= $this->section244607ab42f64f3e7b0f1d4b2d5b2758($context, $indent, $value);
                $buffer .= '"
';
                $context->pop();
            }
        }
    
        return $buffer;
    }

    private function sectionA012885b20c16f143b6281f329058f41(Mustache_Context $context, $indent, $value)
    {
        $buffer = '';
    
        if (!is_string($value) && is_callable($value)) {
            $source = ' {{sectionname}} ';
            $result = (string) call_user_func($value, $source, $this->lambdaHelper);
            $buffer .= $result;
        } elseif (!empty($value)) {
            $values = $this->isIterable($value) ? $value : array($value);
            foreach ($values as $value) {
                $context->push($value);
                
                $buffer .= ' ';
                $value = $this->resolveValue($context->find('sectionname'), $context);
                $buffer .= ($value === null ? '' : call_user_func($this->mustache->getEscape(), $value));
                $buffer .= ' ';
                $context->pop();
            }
        }
    
        return $buffer;
    }

    private function sectionC48ed2934ddbe2ce29e12e8ebc17460b(Mustache_Context $context, $indent, $value)
    {
        $buffer = '';
    
        if (!is_string($value) && is_callable($value)) {
            $source = 'insertcontentsection, core, { "sectionname": {{#quote}} {{sectionname}} {{/quote}} } ';
            $result = (string) call_user_func($value, $source, $this->lambdaHelper);
            $buffer .= $result;
        } elseif (!empty($value)) {
            $values = $this->isIterable($value) ? $value : array($value);
            foreach ($values as $value) {
                $context->push($value);
                
                $buffer .= 'insertcontentsection, core, { "sectionname": ';
                $value = $context->find('quote');
                $buffer .= $this->sectionA012885b20c16f143b6281f329058f41($context, $indent, $value);
                $buffer .= ' } ';
                $context->pop();
            }
        }
    
        return $buffer;
    }

    private function section5aea184c6a232a3dbce55dc55666255b(Mustache_Context $context, $indent, $value)
    {
        $buffer = '';
    
        if (!is_string($value) && is_callable($value)) {
            $source = 'addcontent, core';
            $result = (string) call_user_func($value, $source, $this->lambdaHelper);
            $buffer .= $result;
        } elseif (!empty($value)) {
            $values = $this->isIterable($value) ? $value : array($value);
            foreach ($values as $value) {
                $context->push($value);
                
                $buffer .= 'addcontent, core';
                $context->pop();
            }
        }
    
        return $buffer;
    }

    private function section9b089e00077ec061918a3e4dd2d05479(Mustache_Context $context, $indent, $value)
    {
        $buffer = '';
    
        if (!is_string($value) && is_callable($value)) {
            $source = ' t/add, core ';
            $result = (string) call_user_func($value, $source, $this->lambdaHelper);
            $buffer .= $result;
        } elseif (!empty($value)) {
            $values = $this->isIterable($value) ? $value : array($value);
            foreach ($values as $value) {
                $context->push($value);
                
                $buffer .= ' t/add, core ';
                $context->pop();
            }
        }
    
        return $buffer;
    }

    private function section2522d158b0509584ae9e4e73dac18980(Mustache_Context $context, $indent, $value)
    {
        $buffer = '';
    
        if (!is_string($value) && is_callable($value)) {
            $source = '
            {{> core/action_link}}
        ';
            $result = (string) call_user_func($value, $source, $this->lambdaHelper);
            $buffer .= $result;
        } elseif (!empty($value)) {
            $values = $this->isIterable($value) ? $value : array($value);
            foreach ($values as $value) {
                $context->push($value);
                
                if ($partial = $this->mustache->loadPartial('core/action_link')) {
                    $buffer .= $partial->renderInternal($context, $indent . '            ');
                }
                $context->pop();
            }
        }
    
        return $buffer;
    }

    private function sectionC710fa7758aea7221eb21755c5c19be7(Mustache_Context $context, $indent, $value)
    {
        $buffer = '';
    
        if (!is_string($value) && is_callable($value)) {
            $source = '
<div class="dropdown">
    <button class="btn add-content d-flex justify-content-center align-items-center p-1 icon-no-margin"
            type="button"
            id="dropdownMenuButton-{{#modid}}{{modid}}{{/modid}}{{^modid}}{{uniqid}}{{/modid}}"
            data-bs-toggle="dropdown"
            data-action="open-addingcontent"
            {{#modid}}
            data-beforemod="{{modid}}"
            aria-label="{{#str}}insertcontentbefore, core, { "activityname": {{#quote}} {{activityname}} {{/quote}} } {{/str}}"
            {{/modid}}
            {{^modid}}
            aria-label="{{#str}}insertcontentsection, core, { "sectionname": {{#quote}} {{sectionname}} {{/quote}} } {{/str}}"
            {{/modid}}
            aria-haspopup="true"
            aria-expanded="false"
            tabindex="0"
            title="{{#str}}addcontent, core{{/str}}"
    >
        {{#pix}} t/add, core {{/pix}}
    </button>
    <div class="dropdown-menu" aria-labelledby="dropdownMenuButton-{{#modid}}{{modid}}{{/modid}}{{^modid}}{{uniqid}}{{/modid}}">
        {{> core_course/addresourceoractivitybutton }}
        {{#actionlinks}}
            {{> core/action_link}}
        {{/actionlinks}}
    </div>
</div>
';
            $result = (string) call_user_func($value, $source, $this->lambdaHelper);
            $buffer .= $result;
        } elseif (!empty($value)) {
            $values = $this->isIterable($value) ? $value : array($value);
            foreach ($values as $value) {
                $context->push($value);
                
                $buffer .= $indent . '<div class="dropdown">
';
                $buffer .= $indent . '    <button class="btn add-content d-flex justify-content-center align-items-center p-1 icon-no-margin"
';
                $buffer .= $indent . '            type="button"
';
                $buffer .= $indent . '            id="dropdownMenuButton-';
                $value = $context->find('modid');
                $buffer .= $this->section3ad11aeb42e26704218191fae63bcb28($context, $indent, $value);
                $value = $context->find('modid');
                if (empty($value)) {
                    
                    $value = $this->resolveValue($context->find('uniqid'), $context);
                    $buffer .= ($value === null ? '' : call_user_func($this->mustache->getEscape(), $value));
                }
                $buffer .= '"
';
                $buffer .= $indent . '            data-bs-toggle="dropdown"
';
                $buffer .= $indent . '            data-action="open-addingcontent"
';
                $value = $context->find('modid');
                $buffer .= $this->sectionA00193c143ddd0475f086db8f2764b8a($context, $indent, $value);
                $value = $context->find('modid');
                if (empty($value)) {
                    
                    $buffer .= $indent . '            aria-label="';
                    $value = $context->find('str');
                    $buffer .= $this->sectionC48ed2934ddbe2ce29e12e8ebc17460b($context, $indent, $value);
                    $buffer .= '"
';
                }
                $buffer .= $indent . '            aria-haspopup="true"
';
                $buffer .= $indent . '            aria-expanded="false"
';
                $buffer .= $indent . '            tabindex="0"
';
                $buffer .= $indent . '            title="';
                $value = $context->find('str');
                $buffer .= $this->section5aea184c6a232a3dbce55dc55666255b($context, $indent, $value);
                $buffer .= '"
';
                $buffer .= $indent . '    >
';
                $buffer .= $indent . '        ';
                $value = $context->find('pix');
                $buffer .= $this->section9b089e00077ec061918a3e4dd2d05479($context, $indent, $value);
                $buffer .= '
';
                $buffer .= $indent . '    </button>
';
                $buffer .= $indent . '    <div class="dropdown-menu" aria-labelledby="dropdownMenuButton-';
                $value = $context->find('modid');
                $buffer .= $this->section3ad11aeb42e26704218191fae63bcb28($context, $indent, $value);
                $value = $context->find('modid');
                if (empty($value)) {
                    
                    $value = $this->resolveValue($context->find('uniqid'), $context);
                    $buffer .= ($value === null ? '' : call_user_func($this->mustache->getEscape(), $value));
                }
                $buffer .= '">
';
                if ($partial = $this->mustache->loadPartial('core_course/addresourceoractivitybutton')) {
                    $buffer .= $partial->renderInternal($context, $indent . '        ');
                }
                $value = $context->find('actionlinks');
                $buffer .= $this->section2522d158b0509584ae9e4e73dac18980($context, $indent, $value);
                $buffer .= $indent . '    </div>
';
                $buffer .= $indent . '</div>
';
                $context->pop();
            }
        }
    
        return $buffer;
    }

}
